//
//  CameraController.swift
//  FrameCraft
//
//  AVCaptureSession 取流 + 拍照 + 手电筒 + 前后切换；
//  无相机权限 / 模拟器时自动降级为演示场景，保证界面永远有画面可分析。
//

import AVFoundation
import UIKit
import Combine

final class CameraController: NSObject, ObservableObject {

    enum Mode {
        case camera
        case demo
    }

    // 输出给界面
    @Published var metrics: SubjectMetrics?
    @Published var evaluation: Evaluation = .empty
    @Published var mode: Mode = .camera
    @Published var isRunning = false
    @Published var denied = false
    @Published var torchOn = false
    @Published var demoImage: UIImage?

    /// 当前变焦倍率（1 = 广角端）。构图软件里"主体占比"这一维要靠它来调，
    /// 只让用户走路靠近是不够的
    @Published var zoomFactor: CGFloat = 1
    /// 本机实际能用的上限，配置会话时按设备能力回填
    @Published private(set) var maxZoom: CGFloat = 1
    /// 拍照进行中：photoCompletion 只有一个槽位，连点会让上一张静默丢掉
    @Published var isCapturing = false
    /// 最近一次点按对焦的位置（取景区归一化坐标，界面据此画对焦框）
    @Published var focusPoint: CGPoint?

    let session = AVCaptureSession()

    /// 取景区域宽高比（由界面回填），用于决定分析时裁掉多少
    var stageAspect: CGFloat = 0.75

    private let sessionQueue = DispatchQueue(label: "framecraft.session")
    private let videoQueue = DispatchQueue(label: "framecraft.video", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var input: AVCaptureDeviceInput?
    private var photoCompletion: ((UIImage?) -> Void)?

    /// 拍照令牌：回调迟到或丢失时用来自动作废，避免快门永久锁死
    private var captureToken = 0
    /// 点按对焦令牌：2 秒后若没有新的点按，才把相机松回连续自动
    private var focusToken = 0
    /// 预热过的触感发生器。每次现建一个会有几帧延迟，快门就"手感发虚"
    private let impact = UIImpactFeedbackGenerator(style: .light)

    private var currentOrientation: UIInterfaceOrientation = .portrait
    private var lastAnalysis: CFTimeInterval = 0
    /// 前置摄像头时预览是镜像的，指标要跟着镜像
    private var usingFront = false
    /// 人脸关键点错帧检测（Vision 成本随像素数线性增长），中间帧复用上一帧结果
    private var faceTick = false
    private var lastFace: FaceInfo?
    /// 时间平滑的上一帧结果（只在 videoQueue 上访问）
    private var smoothed: SubjectMetrics?
    private var lastFrameTime: CFTimeInterval = 0

    private var observingLifecycle = false
    private var demoLink: CADisplayLink?
    private var demoPhase: CGFloat = 0
    private var demoLastTick: CFTimeInterval = 0

    // MARK: - 生命周期

    func start() {
        registerLifecycle()
        impact.prepare()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if granted {
                        self.configureSession()
                    } else {
                        self.denied = true
                        self.startDemo()
                    }
                }
            }
        default:
            denied = true
            startDemo()
        }
    }

    /// iOS 会把后台的采集会话挂起，回前台必须手动重启，否则取景黑屏
    private func registerLifecycle() {
        guard !observingLifecycle else { return }
        observingLifecycle = true
        let center = NotificationCenter.default

        center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                           object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.sessionQueue.async {
                if self.session.isRunning { self.session.stopRunning() }
            }
        }

        center.addObserver(forName: UIApplication.willEnterForegroundNotification,
                           object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.sessionQueue.async {
                if !self.session.isRunning && !self.session.inputs.isEmpty {
                    self.session.startRunning()
                }
                let running = self.session.isRunning
                DispatchQueue.main.async { self.isRunning = running }
            }
        }
    }

    func stop() {
        demoLink?.invalidate()
        demoLink = nil
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    // MARK: - 会话配置

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.inputs.isEmpty {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                           for: .video, position: .back),
                      let deviceInput = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(deviceInput)
                else {
                    DispatchQueue.main.async { self.startDemo() }
                    return
                }

                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                self.session.addInput(deviceInput)
                self.input = deviceInput
                self.usingFront = (device.position == .front)

                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.videoQueue)
                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                    self.videoOutput = output
                }
                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }
                // 分析吃原始帧：镜像在指标层补，保证与镜像预览一致
                self.forceUnmirrored()
                self.session.commitConfiguration()
                self.applyOrientation()
                self.session.startRunning()
                // 上限取设备能力与 5x 的较小值：再往上全是数字插值，糊成噪点，对构图没有帮助
                let upper = min(device.activeFormat.videoMaxZoomFactor, 5)
                DispatchQueue.main.async {
                    self.isRunning = true
                    self.mode = .camera
                    self.maxZoom = max(1, upper)
                    self.zoomFactor = 1
                }
            } else if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = true
                    self.mode = .camera
                }
            }
        }
    }

    // MARK: - 方向

    func setOrientation(_ orientation: UIInterfaceOrientation) {
        guard orientation != currentOrientation else { return }
        currentOrientation = orientation
        applyOrientation()
    }

    /// 让视频数据输出保持未镜像：预览层对前置是镜像的，指标层再做一次镜像即可对齐。
    /// 必须在 beginConfiguration/commitConfiguration 之间调用，运行期改会抛异常。
    private func forceUnmirrored() {
        guard let conn = videoOutput?.connection(with: .video),
              conn.isVideoMirroringSupported else { return }
        conn.automaticallyAdjustsVideoMirroring = false
        conn.isVideoMirrored = false
    }

    private func applyOrientation() {
        // UIInterfaceOrientation 与 AVCaptureVideoOrientation 在横屏时是反的，必须显式映射
        let target: AVCaptureVideoOrientation
        switch currentOrientation {
        case .portrait:            target = .portrait
        case .portraitUpsideDown:  target = .portraitUpsideDown
        case .landscapeLeft:       target = .landscapeRight
        case .landscapeRight:      target = .landscapeLeft
        default:                   target = .portrait
        }

        if let conn = videoOutput?.connection(with: .video), conn.isVideoOrientationSupported {
            conn.videoOrientation = target
        }
        if let conn = photoOutput.connection(with: .video), conn.isVideoOrientationSupported {
            conn.videoOrientation = target
        }
    }

    // MARK: - 镜头切换 / 手电筒

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self, let current = self.input else { return }
            let target: AVCaptureDevice.Position =
                (current.device.position == .back) ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video, position: target),
                  let newInput = try? AVCaptureDeviceInput(device: device) else { return }

            self.session.beginConfiguration()
            self.session.removeInput(current)
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.input = newInput
                self.usingFront = (newInput.device.position == .front)
            } else {
                self.session.addInput(current)
                self.usingFront = (current.device.position == .front)
            }
            self.forceUnmirrored()
            self.session.commitConfiguration()
            self.applyOrientation()
            // 换了镜头，变焦范围和对焦点都不再成立，全部归位
            self.focusToken += 1
            self.videoQueue.async {
                // 画面内容全变了，平滑状态要清掉，否则第一帧会从旧主体的位置滑过来
                self.smoothed = nil
            }
            let upper = min(newInput.device.activeFormat.videoMaxZoomFactor, 5)
            DispatchQueue.main.async {
                self.torchOn = false
                self.zoomFactor = 1
                self.maxZoom = max(1, upper)
                self.focusPoint = nil
            }
        }
    }

    func toggleTorch() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.input?.device,
                  device.hasTorch, device.isTorchAvailable,
                  (try? device.lockForConfiguration()) != nil
            else { return }
            device.torchMode = (device.torchMode == .on) ? .off : .on
            let on = (device.torchMode == .on)
            device.unlockForConfiguration()
            DispatchQueue.main.async { self.torchOn = on }
        }
    }

    // MARK: - 变焦

    /// 设定倍率。捏合手势会以 60Hz 的节奏喊它，所以这里只做夹取 + 一次 lock，
    /// 不加动画——手势本身已经是连续的，再叠一层 ramp 反而跟手度变差
    func setZoom(_ factor: CGFloat) {
        guard mode == .camera else { return }
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.input?.device else { return }
            let upper = max(1, min(device.activeFormat.videoMaxZoomFactor, self.maxZoom))
            let target = min(max(factor, 1), upper)
            guard (try? device.lockForConfiguration()) != nil else { return }
            device.videoZoomFactor = target
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                // 手势给的原始值可能是 3.7，界面要显示"3.7x"，所以回填夹取后的真实值
                self.zoomFactor = target
            }
        }
    }

    /// 点一下倍率按钮走的路径：有动画地推过去，视觉上比瞬移舒服
    func rampZoom(to factor: CGFloat) {
        guard mode == .camera else { return }
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.input?.device else { return }
            let upper = max(1, min(device.activeFormat.videoMaxZoomFactor, self.maxZoom))
            let target = min(max(factor, 1), upper)
            guard (try? device.lockForConfiguration()) != nil else { return }
            if device.videoZoomFactor != target {
                device.ramp(toVideoZoomFactor: target, withRate: 12)
            }
            device.unlockForConfiguration()
            DispatchQueue.main.async { self.zoomFactor = target }
        }
    }

    // MARK: - 点按对焦 / 曝光

    /// devicePoint 由 AVCaptureVideoPreviewLayer 换算好的设备坐标（0…1），
    /// viewPoint 是屏幕坐标，只用来画对焦框，两者不要混用
    func focus(at devicePoint: CGPoint, viewPoint: CGPoint) {
        guard mode == .camera else { return }
        focusPoint = viewPoint

        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.input?.device else { return }
            self.focusToken += 1
            let token = self.focusToken

            if (try? device.lockForConfiguration()) != nil {
                if device.isFocusPointOfInterestSupported,
                   device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported,
                   device.isExposureModeSupported(.autoExposure) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            }

            // AVFoundation 没有"对焦完成"回调，只能靠计时松开；
            // 不松的话用户点了别处之后焦点会一直锁在老位置，越拍越糊
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                self.sessionQueue.async {
                    guard self.focusToken == token else { return }   // 期间又点了一次，别抢
                    guard let device = self.input?.device else { return }
                    guard (try? device.lockForConfiguration()) != nil else { return }
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    device.unlockForConfiguration()
                }
            }
        }
    }

    /// 双击回到画面中心对焦并解锁测光
    func resetFocusAndExposure() {
        guard mode == .camera else { return }
        focusPoint = nil
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.input?.device else { return }
            self.focusToken += 1
            guard (try? device.lockForConfiguration()) != nil else { return }
            let center = CGPoint(x: 0.5, y: 0.5)
            if device.isFocusPointOfInterestSupported,
               device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusPointOfInterest = center
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported,
               device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = center
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        }
    }

    // MARK: - 拍照

    func capturePhoto(_ completion: @escaping (UIImage?) -> Void) {
        if mode == .demo {
            impact.impactOccurred()
            completion(demoImage)
            return
        }
        guard isRunning else {
            completion(nil)
            return
        }
        // photoCompletion 只有一个槽位：连点时第二次会直接覆盖掉第一次的回调，
        // 那张照片就静默丢了。这里直接拒绝，快门也不会给出错误反馈
        guard !isCapturing else { return }

        isCapturing = true
        impact.impactOccurred()
        impact.prepare()

        photoCompletion = completion
        captureToken += 1
        let token = captureToken

        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .balanced
        applyOrientation()
        photoOutput.capturePhoto(with: settings, delegate: self)

        // 兜底：万一 delegate 回调没来（会话被打断、内存吃紧），快门不能永远锁着
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self = self, self.captureToken == token, self.isCapturing else { return }
            self.photoCompletion = nil
            self.isCapturing = false
        }
    }

    // MARK: - 演示场景（模拟器 / 无权限）

    func startDemo() {
        guard demoLink == nil else { return }
        mode = .demo
        let link = CADisplayLink(target: self, selector: #selector(demoTick))
        link.preferredFramesPerSecond = 8
        link.add(to: .main, forMode: .common)
        demoLink = link
        renderDemoFrame()
    }

    @objc private func demoTick() {
        let now = CACurrentMediaTime()
        if now - demoLastTick < 0.12 { return }
        demoLastTick = now
        demoPhase += 0.09
        renderDemoFrame()
    }

    private func renderDemoFrame() {
        let image = DemoScene.render(size: CGSize(width: 600, height: 800), phase: demoPhase)
        demoImage = image
        // 演示场景是程序绘制的剪影，没有人脸可检，跑 Vision 只是白占主线程
        if let m = FrameAnalyzer.analyze(image: image, detectFace: false) {
            metrics = m
            evaluation = CompositionEngine.evaluate(m)
        }
    }
}

// MARK: - 视频帧

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        if now - lastAnalysis < 0.10 { return }     // 10fps 足够，省电
        lastAnalysis = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let aspect = stageAspect
        let wantFace = faceTick
        faceTick.toggle()
        guard var m = FrameAnalyzer.analyze(pixelBuffer: pixelBuffer,
                                           stageAspect: aspect,
                                           detectFace: wantFace)
        else { return }
        // 未检测的这一帧沿用上次的人脸（100ms 内位置几乎不变），避免人像维度闪烁
        if wantFace {
            lastFace = m.face
        } else {
            m.face = lastFace
        }
        // 先平滑再镜像：镜像只是坐标翻转，平滑系数与坐标系无关。
        // 平滑发生在评分之前，因此"看到的框"和"算出的分"始终是同一份数据
        m = stabilized(m, at: now)
        if usingFront { m = m.mirrored() }
        let ev = CompositionEngine.evaluate(m)

        DispatchQueue.main.async {
            self.metrics = m
            self.evaluation = ev
        }
    }

    /// 主体框 / 质心的时间平滑。
    /// 逐帧独立出框的结果每帧都不一样，直接画出来会持续抖动——观感上是"框在呼吸"，
    /// 而构图引导最怕的就是让用户怀疑指标准不准。
    /// 位置比尺寸敏感，所以位置系数大；面积突变（换了拍摄对象、大幅推拉）时直接跳过去，不留拖尾。
    private func stabilized(_ input: SubjectMetrics, at now: CFTimeInterval) -> SubjectMetrics {
        guard let prev = smoothed, now - lastFrameTime < 0.45 else {
            smoothed = input
            lastFrameTime = now
            return input
        }
        lastFrameTime = now

        let prevArea = max(prev.box.width * prev.box.height, 0.0001)
        let newArea = max(input.box.width * input.box.height, 0.0001)
        let shift = newArea / prevArea
        if shift > 2.2 || shift < 0.45 {
            smoothed = input
            return input
        }

        // 死区：0.4% 以内的位移直接忽略（约 2pt，肉眼看不到）。
        // 没有这一层，主体明明没动框还是会轻轻颤——那是对比度噪声，不是构图变化
        if abs(input.box.minX - prev.box.minX) < 0.004,
           abs(input.box.minY - prev.box.minY) < 0.004,
           abs(input.box.width - prev.box.width) < 0.004 {
            return prev
        }

        let kPos: CGFloat = 0.35      // 位置跟随
        let kSize: CGFloat = 0.22     // 尺寸跟随

        var out = input
        out.box = CGRect(x: prev.box.minX + (input.box.minX - prev.box.minX) * kPos,
                         y: prev.box.minY + (input.box.minY - prev.box.minY) * kPos,
                         width: prev.box.width + (input.box.width - prev.box.width) * kSize,
                         height: prev.box.height + (input.box.height - prev.box.height) * kSize)
        // area 的定义就是包围盒面积，平滑了框就必须同步，否则标签上的百分比和框对不上
        out.area = out.box.width * out.box.height
        out.centroid = CGPoint(x: prev.centroid.x + (input.centroid.x - prev.centroid.x) * kPos,
                               y: prev.centroid.y + (input.centroid.y - prev.centroid.y) * kPos)
        out.symAxis = prev.symAxis + (input.symAxis - prev.symAxis) * kPos
        out.balanceLR = prev.balanceLR + (input.balanceLR - prev.balanceLR) * kPos
        out.balanceTB = prev.balanceTB + (input.balanceTB - prev.balanceTB) * kPos
        out.tilt = prev.tilt + (input.tilt - prev.tilt) * kPos
        out.horizonY = prev.horizonY + (input.horizonY - prev.horizonY) * kPos
        out.clutter = prev.clutter + (input.clutter - prev.clutter) * kSize

        // 人脸位置也要平滑，否则"人像细节"那一维会以同样的节奏跳分
        if var f = input.face, let pf = prev.face {
            f.box = CGRect(x: pf.box.minX + (f.box.minX - pf.box.minX) * kPos,
                           y: pf.box.minY + (f.box.minY - pf.box.minY) * kPos,
                           width: pf.box.width + (f.box.width - pf.box.width) * kSize,
                           height: pf.box.height + (f.box.height - pf.box.height) * kSize)
            f.eyeMidX = pf.eyeMidX + (f.eyeMidX - pf.eyeMidX) * kPos
            f.eyeLineY = pf.eyeLineY + (f.eyeLineY - pf.eyeLineY) * kPos
            f.headroom = pf.headroom + (f.headroom - pf.headroom) * kSize
            f.turn = pf.turn + (f.turn - pf.turn) * kPos
            out.face = f
        }

        smoothed = out
        return out
    }
}

// MARK: - 拍照回调

extension CameraController: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        var image: UIImage?
        if error == nil, let data = photo.fileDataRepresentation() {
            image = UIImage(data: data)
        }
        let completion = photoCompletion
        photoCompletion = nil
        DispatchQueue.main.async {
            // 令牌推进一格，让 4 秒兜底失效——否则它会误清掉下一次拍照的状态
            self.captureToken += 1
            self.isCapturing = false
            completion?(image)
        }
    }
}

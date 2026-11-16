//
//  CameraView.swift
//  FrameCraft
//
//  取景主界面：预览 + 构图叠加层 + HUD + 控制区
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraView: View {

    @EnvironmentObject var camera: CameraController
    @EnvironmentObject var album: AlbumStore

    @State private var aspectIndex = 1
    @State private var grid: GridMode = .thirds
    @State private var smartCrop = true
    @State private var stageSize: CGSize = .zero
    /// 控制面板实际高度：画幅引导框要躲开它，否则竖幅框会有一截钻到面板底下
    @State private var panelHeight: CGFloat = 0
    @State private var review: ReviewPayload?
    @State private var showSpec = false
    @State private var showAlbum = false
    @State private var flashOpacity: Double = 0
    @State private var toastText: String?

    /// 点按对焦框是否可见（1.1 秒后淡出）
    @State private var focusVisible = false
    /// 对焦框令牌：连点时只有最后一次的淡出定时器能生效
    @State private var focusMarkID = 0
    /// 捏合变焦的基准倍率，手势开始时记一次
    @State private var pinchAnchor: CGFloat = 1

    var body: some View {
        ZStack(alignment: .bottom) {
            // ① 画布层：预览、构图叠加、对焦框共用同一坐标系，整体铺到屏幕四边
            viewfinder

            // ② 界面层：完全摆在安全区内。
            //    分层之后"被状态栏/灵动岛挡住"在结构上就不会发生，
            //    不用再手算 topInset —— 之前 GeometryReader 上挂了 ignoresSafeArea，
            //    读到的 safeAreaInsets 全是 0，圆环才会顶到时间下面去
            chrome
        }
        .background(Theme.bg)
        .preferredColorScheme(.dark)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .fullScreenCover(item: $review) { payload in
            ReviewView(
                payload: payload,
                onRetake: {
                    review = nil
                    showToast("回到取景，按左边建议调整")
                },
                onKeep: { image, ev in
                    album.add(image, score: ev.total, rule: ev.rule)
                    review = nil
                    showToast("已存入相册 · 构图分 \(ev.total)")
                },
                onSaveToLibrary: { image in
                    album.saveToLibrary(image) { ok in
                        showToast(ok ? "已保存到系统相册" : "保存失败，请检查相册权限")
                    }
                }
            )
        }
        .sheet(isPresented: $showSpec) { SpecView() }
        .sheet(isPresented: $showAlbum) { AlbumView(album: album) }
    }

    // MARK: - 取景区

    /// 画布。预览、构图叠加、对焦框三者用同一套归一化坐标，
    /// 必须待在同一个容器里 —— 一旦各自忽略安全区，框就会和画面错位
    private var viewfinder: some View {
        ZStack {
            if camera.mode == .demo, let img = camera.demoImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                CameraPreview(session: camera.session,
                              onOrientation: { camera.setOrientation($0) },
                              onTap: handleTap,
                              onDoubleTap: {
                                  camera.resetFocusAndExposure()
                                  hideFocusMark()
                              },
                              onPinch: handlePinch)
            }

            OverlayLayer(metrics: camera.metrics,
                         evaluation: camera.evaluation,
                         crop: cropRect(),
                         grid: grid)

            focusReticle

            Color.white
                .opacity(flashOpacity)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(Theme.bg)
        .background(
            GeometryReader { g in
                Color.clear
                    .onAppear { updateStage(g.size) }
                    .onChange(of: g.size) { newSize in updateStage(newSize) }
            }
        )
        .ignoresSafeArea()
    }

    /// 点按的一下要有回执：没有这个框，用户不知道刚才那下到底生效没有
    private var focusReticle: some View {
        Group {
            if let p = camera.focusPoint, focusVisible {
                FocusReticle()
                    .position(p)
                    // 按令牌重建：否则从画面一侧点到另一侧时，框会滑过去而不是跳过去
                    .id(focusMarkID)
                    .transition(.scale(scale: 1.7).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
    }

    /// 界面层：一条竖排，从安全区顶部到底部。
    /// 顶部只放读数，底部依次是 Toast → 构图提示 → 控制面板，
    /// 三者是 VStack 的兄弟节点，所以不会互相压住
    private var chrome: some View {
        VStack(spacing: 0) {
            hud

            Spacer(minLength: 0)

            if let t = toastText {
                toastChip(t)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            tipsBlock
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            controlPanel
        }
    }

    private func toastChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Theme.panel2))
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
            .foregroundColor(Color(white: 0.9))
    }

    private var tipsBlock: some View {
        VStack(spacing: 6) {
            if camera.metrics == nil {
                TipRow(text: "画面缺少明确主体 —— 对准有明暗或颜色落差的物体，或靠近一点。")
            } else if camera.evaluation.tips.isEmpty && wideSubjectHint == nil {
                TipRow(text: "主体位置、占比、水平都到位，按你的想法按下快门。", ok: true)
            } else {
                // 有画幅提示时只留最要紧的一条，免得把新提示挤出屏幕
                let limit = wideSubjectHint == nil ? 2 : 1
                ForEach(Array(camera.evaluation.tips.prefix(limit))) { tip in
                    TipRow(text: tip.text)
                }
                if let hint = wideSubjectHint {
                    TipRow(text: hint)
                }
            }
        }
    }

    private var hud: some View {
        HStack(alignment: .top, spacing: 11) {
            ScoreRing(score: camera.evaluation.total)

            VStack(alignment: .leading, spacing: 6) {
                Text(camera.denied ? "相机权限被拒，正在播放演示场景"
                                   : camera.evaluation.verdict)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.85), radius: 4)

                HStack(spacing: 5) {
                    Chip(text: camera.evaluation.scene)
                    Chip(text: camera.evaluation.rule, accent: true)
                    Chip(text: String(format: "%.1f° 水平",
                                      Double(abs(camera.metrics?.tilt ?? 0))))
                }
            }

            Spacer(minLength: 0)

            Button { showSpec = true } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    /// 变焦是构图软件里唯一能立刻改变"主体占比"的旋钮：
    /// 只靠走近退后，一是慢，二是很多场景根本走不了
    private var showsZoomBar: Bool {
        camera.mode == .camera && camera.maxZoom > 1.01
    }

    private var zoomPills: some View {
        HStack(spacing: 3) {
            ForEach(zoomStops, id: \.self) { stop in
                Button { camera.rampZoom(to: stop) } label: {
                    Text(zoomLabel(stop))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(isZoomCurrent(stop)
                                         ? Color(red: 0.12, green: 0.09, blue: 0.02)
                                         : .white)
                        .frame(width: 36, height: 28)
                        .background(Capsule().fill(isZoomCurrent(stop)
                                                   ? Theme.amber
                                                   : Color.black.opacity(0.42)))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.black.opacity(0.24)))
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var zoomStops: [CGFloat] {
        [1, 2, 3].filter { $0 <= camera.maxZoom + 0.05 }
    }

    private func zoomLabel(_ value: CGFloat) -> String {
        value == value.rounded() ? "\(Int(value))x" : String(format: "%.1fx", value)
    }

    private func isZoomCurrent(_ value: CGFloat) -> Bool {
        abs(camera.zoomFactor - value) < 0.12
    }

    /// 竖幅比例装不下横向铺开的主体——"画幅选错了"最典型的表现。
    /// 阈值给得比较硬，就是为了别让它在正常画面上乱冒
    private var wideSubjectHint: String? {
        guard let m = camera.metrics else { return nil }
        guard AspectPreset.all[aspectIndex].value < 0.95 else { return nil }
        guard m.box.width > 0.34, m.box.height > 0.04 else { return nil }
        guard m.box.width / m.box.height > 1.5 else { return nil }
        return "主体是横向铺开的，竖幅装不下 —— 换成 16:9 横着拍"
    }

    // MARK: - 控制区

    /// 控制面板。变焦键从这里进来，不再浮在画面中间挡主体 ——
    /// 它是"控制"，就该和其他控制待在一起
    private var controlPanel: some View {
        VStack(spacing: 8) {
            if showsZoomBar {
                zoomPills
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(spacing: 6) {
                ForEach(0..<AspectPreset.all.count, id: \.self) { idx in
                    let opt = AspectPreset.all[idx]
                    Button { aspectIndex = idx } label: {
                        Text(opt.label)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(idx == aspectIndex ? Theme.amber.opacity(0.15)
                                                             : Theme.panel2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(idx == aspectIndex ? Theme.amber.opacity(0.45)
                                                               : Color.clear, lineWidth: 1)
                            )
                            .foregroundColor(idx == aspectIndex ? Theme.amber : Color(white: 0.68))
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            HStack(spacing: 6) {
                SmallPill(title: grid.label, active: grid != .off) { grid = grid.next }
                SmallPill(title: "智能裁剪", active: smartCrop) { smartCrop.toggle() }
                SmallPill(title: camera.torchOn ? "手电开" : "手电",
                          active: camera.torchOn) { camera.toggleTorch() }
                Spacer(minLength: 0)
            }

            HStack {
                Button { showAlbum = true } label: {
                    Group {
                        if let latest = album.shots.first {
                            Image(uiImage: latest.image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 16))
                                .foregroundColor(Color(white: 0.7))
                        }
                    }
                    .frame(width: 46, height: 46)
                    .background(Theme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())

                Spacer()

                Button(action: shoot) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 4)
                            .frame(width: 66, height: 66)
                        Circle()
                            .fill(camera.isCapturing ? Theme.amber : Color.white)
                            .frame(width: camera.isCapturing ? 44 : 58,
                                   height: camera.isCapturing ? 44 : 58)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
                    .animation(.easeOut(duration: 0.16), value: camera.isCapturing)
                }
                .buttonStyle(PressableStyle())

                Spacer()

                Button { camera.switchCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 19))
                        .foregroundColor(Color(white: 0.8))
                        .frame(width: 46, height: 46)
                        .background(Theme.panel2)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        // 面板底色往 Home 指示条那片区域延伸，内容仍留在安全区内
        .background(Theme.panel.ignoresSafeArea(edges: .bottom))
        .background(
            GeometryReader { g in
                Color.clear
                    .onAppear { panelHeight = g.size.height }
                    .onChange(of: g.size) { newSize in panelHeight = newSize.height }
            }
        )
    }

    // MARK: - 几何

    private func updateStage(_ size: CGSize) {
        guard size.width > 10, size.height > 10 else { return }
        stageSize = size
        camera.stageAspect = size.width / size.height
    }

    private func cropRect() -> CGRect {
        guard stageSize.width > 10, stageSize.height > 10 else { return .zero }
        // 只用"面板以上的可见部分"来算构图框，否则 9:16 这类竖幅框
        // 会有一部分被控制面板盖住，看起来像画幅算错了
        let visible = CGSize(width: stageSize.width,
                             height: max(160, stageSize.height - panelHeight))
        return CompositionEngine.suggestCrop(size: visible,
                                             aspect: AspectPreset.all[aspectIndex].value,
                                             metrics: camera.metrics,
                                             smart: smartCrop)
    }

    // MARK: - 取景交互

    /// viewPoint 用来画框，devicePoint 交给相机对焦——两者坐标系不同，不能混用
    private func handleTap(viewPoint: CGPoint, devicePoint: CGPoint) {
        guard camera.mode == .camera else { return }
        // 底部这条被提示条和控制面板占着，点它们是想要调参而不是想对焦。
        // 不挡的话，点一下 2x 会顺手把焦点挪到画面下沿，拍人像时正好落在衣服上
        guard stageSize.height > 10 else { return }
        let reserved = panelHeight > 0 ? panelHeight + 8
                                       : min(130, stageSize.height * 0.25)
        guard viewPoint.y > 70,
              viewPoint.y < stageSize.height - reserved else { return }

        camera.focus(at: devicePoint, viewPoint: viewPoint)

        focusMarkID += 1
        let id = focusMarkID
        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) { focusVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            // 连点时旧的定时器不能把新的框收掉
            guard focusMarkID == id else { return }
            withAnimation(.easeOut(duration: 0.32)) { focusVisible = false }
        }
    }

    private func hideFocusMark() {
        focusMarkID += 1
        withAnimation(.easeOut(duration: 0.25)) { focusVisible = false }
    }

    /// UIKit 只给累计倍数，所以基准在 began 时记一次，之后都按 "基准 × 倍数" 算，
    /// 这样连续捏合不会因为累乘而跑飞
    private func handlePinch(_ scale: CGFloat, _ phase: PinchPhase) {
        switch phase {
        case .began:
            pinchAnchor = camera.zoomFactor
        case .changed:
            camera.setZoom(pinchAnchor * scale)
        case .ended:
            pinchAnchor = camera.zoomFactor
        }
    }

    // MARK: - 拍摄

    private func shoot() {
        // 拍照进行中直接无视：CameraController 那边也会拦，但这里提前挡住能省一次闪白
        guard !camera.isCapturing else { return }

        withAnimation(.easeOut(duration: 0.06)) { flashOpacity = 0.92 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.easeOut(duration: 0.22)) { flashOpacity = 0 }
        }

        camera.capturePhoto { image in
            guard let image = image else {
                showToast("这一帧没抓到内容，再试一次")
                return
            }
            buildReview(from: image)
        }
    }

    private func buildReview(from original: UIImage) {
        let aspectValue = AspectPreset.all[aspectIndex].value
        let smart = smartCrop
        let liveMetrics = camera.metrics
        let stageAspect = camera.stageAspect

        // 重活放后台：解码 + 两次分析
        DispatchQueue.global(qos: .userInitiated).async {
            let upright = original.normalized()
            let aspect = stageAspect > 0.3 ? stageAspect
                                           : upright.size.width / max(1, upright.size.height)
            let visible = upright.centerCropped(to: aspect)
            let small = visible.resized(maxWidth: 720)

            let beforeMetrics = FrameAnalyzer.analyze(image: small)
            let beforeEval = beforeMetrics.map { CompositionEngine.evaluate($0) } ?? .empty

            let place = liveMetrics ?? beforeMetrics
            let cropRect = CompositionEngine.suggestCrop(size: visible.size,
                                                         aspect: aspectValue,
                                                         metrics: place,
                                                         smart: smart)
            let reframed = visible.cropped(to: cropRect)
            let afterMetrics = FrameAnalyzer.analyze(image: reframed.resized(maxWidth: 720))
            let afterEval = afterMetrics.map { CompositionEngine.evaluate($0) }
                ?? CompositionEngine.evaluate(place ?? SubjectMetrics())

            let payload = ReviewPayload(
                original: visible,
                reframed: reframed,
                cropAspect: cropRect.width / max(1, cropRect.height),
                before: beforeEval,
                after: afterEval)

            DispatchQueue.main.async { self.review = payload }
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { toastText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.easeIn(duration: 0.2)) { toastText = nil }
        }
    }
}

// MARK: - 拍照结果

struct ReviewPayload: Identifiable {
    let id = UUID()
    let original: UIImage
    let reframed: UIImage
    let cropAspect: CGFloat
    let before: Evaluation
    let after: Evaluation
}

// MARK: - 预览层

/// 捏合手势的阶段。UIKit 只给累计倍数，缩放基准要由调用方在 began 时记一次
enum PinchPhase {
    case began, changed, ended
}

final class PreviewView: UIView {

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }

    var onOrientation: ((UIInterfaceOrientation) -> Void)?

    /// 点按取景，回传 (屏幕点, 设备坐标点)。
    /// 设备坐标必须让 previewLayer 自己换算：它会一并处理 resizeAspectFill 的裁切、
    /// 前置镜像和画幅方向，手写这套矩阵十有八九会把镜像搞反
    var onTap: ((CGPoint, CGPoint) -> Void)?
    /// 双击：复位对焦与测光
    var onDoubleTap: (() -> Void)?
    /// 捏合变焦：(累计倍数, 阶段)
    var onPinch: ((CGFloat, PinchPhase) -> Void)?

    private let singleTap = UITapGestureRecognizer()
    private let doubleTap = UITapGestureRecognizer()
    private let pinch = UIPinchGestureRecognizer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpGestures()
    }

    private func setUpGestures() {
        singleTap.addTarget(self, action: #selector(handleSingle(_:)))
        doubleTap.addTarget(self, action: #selector(handleDouble(_:)))
        doubleTap.numberOfTapsRequired = 2
        // 双击优先，单点要等双击判定失败——否则双击会先闪一下对焦框
        singleTap.require(toFail: doubleTap)
        pinch.addTarget(self, action: #selector(handlePinch(_:)))

        addGestureRecognizer(singleTap)
        addGestureRecognizer(doubleTap)
        addGestureRecognizer(pinch)
    }

    @objc private func handleSingle(_ g: UITapGestureRecognizer) {
        guard bounds.width > 1, bounds.height > 1 else { return }
        let point = g.location(in: self)
        let device = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        onTap?(point, device)
    }

    @objc private func handleDouble(_ g: UITapGestureRecognizer) {
        onDoubleTap?()
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .began:   onPinch?(g.scale, .began)
        case .changed: onPinch?(g.scale, .changed)
        case .ended, .cancelled, .failed: onPinch?(g.scale, .ended)
        default: break
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let scene = window?.windowScene {
            onOrientation?(scene.interfaceOrientation)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onOrientation: (UIInterfaceOrientation) -> Void
    var onTap: ((CGPoint, CGPoint) -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil
    var onPinch: ((CGFloat, PinchPhase) -> Void)? = nil

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onOrientation = onOrientation
        view.onTap = onTap
        view.onDoubleTap = onDoubleTap
        view.onPinch = onPinch
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.onOrientation = onOrientation
        uiView.onTap = onTap
        uiView.onDoubleTap = onDoubleTap
        uiView.onPinch = onPinch
    }
}

// MARK: - 对焦框

struct FocusReticle: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.amber, lineWidth: 1.6)
                .frame(width: 64, height: 64)
            RoundedRectangle(cornerRadius: 2)
                .stroke(Theme.amber.opacity(0.34), lineWidth: 1)
                .frame(width: 44, height: 44)
        }
        .shadow(color: .black.opacity(0.45), radius: 3)
    }
}

// MARK: - 叠加层

struct OverlayLayer: View {
    let metrics: SubjectMetrics?
    let evaluation: Evaluation
    let crop: CGRect
    let grid: GridMode

    var body: some View {
        Canvas { context, size in
            drawGrid(&context, size)
            drawCrop(&context, size)
            if let m = metrics {
                drawSubject(&context, size, m)
                if let f = m.face {
                    drawFace(&context, size, f)
                }
            }
            drawLevel(&context, size)
        }
        .allowsHitTesting(false)
    }

    private func drawGrid(_ ctx: inout GraphicsContext, _ size: CGSize) {
        guard grid != .off else { return }
        var path = Path()
        switch grid {
        case .thirds:
            for i in 1...2 {
                let x = size.width * CGFloat(i) / 3
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                let y = size.height * CGFloat(i) / 3
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(.white.opacity(0.30)), lineWidth: 1)
        case .golden:
            for t in [0.382, 0.618] {
                let x = size.width * t
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                let y = size.height * t
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(.white.opacity(0.26)), lineWidth: 1)
            var dot = Path()
            dot.addEllipse(in: CGRect(x: size.width * 0.618 - 3.5,
                                      y: size.height * 0.382 - 3.5,
                                      width: 7, height: 7))
            ctx.stroke(dot, with: .color(Theme.amber.opacity(0.5)), lineWidth: 1)
        case .center:
            path.move(to: CGPoint(x: size.width / 2, y: 0))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            let r = min(size.width, size.height) * 0.10
            path.addEllipse(in: CGRect(x: size.width / 2 - r, y: size.height / 2 - r,
                                       width: r * 2, height: r * 2))
            ctx.stroke(path, with: .color(.white.opacity(0.32)), lineWidth: 1)
        case .sym:
            path.move(to: CGPoint(x: size.width / 2, y: 0))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            ctx.stroke(path, with: .color(.white.opacity(0.32)), lineWidth: 1)
            var dashed = Path()
            for x in [0.25, 0.75] {
                dashed.move(to: CGPoint(x: size.width * x, y: 0))
                dashed.addLine(to: CGPoint(x: size.width * x, y: size.height))
            }
            ctx.stroke(dashed, with: .color(.white.opacity(0.18)),
                       style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
        case .off:
            break
        }
    }

    private func drawCrop(_ ctx: inout GraphicsContext, _ size: CGSize) {
        guard crop.width > 8, size.width > 8 else { return }

        var mask = Path(CGRect(origin: .zero, size: size))
        mask.addRect(crop)
        ctx.fill(mask, with: .color(.black.opacity(0.34)), style: FillStyle(eoFill: true))

        ctx.stroke(Path(crop), with: .color(.white.opacity(0.55)), lineWidth: 1)

        // 四角括号
        let len = min(crop.width, crop.height) * 0.055
        var corners = Path()
        let pts: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: crop.minX, y: crop.minY), 1, 1),
            (CGPoint(x: crop.maxX, y: crop.minY), -1, 1),
            (CGPoint(x: crop.minX, y: crop.maxY), 1, -1),
            (CGPoint(x: crop.maxX, y: crop.maxY), -1, -1)
        ]
        for p in pts {
            corners.move(to: CGPoint(x: p.0.x, y: p.0.y + p.2 * len))
            corners.addLine(to: p.0)
            corners.addLine(to: CGPoint(x: p.0.x + p.1 * len, y: p.0.y))
        }
        ctx.stroke(corners, with: .color(.white.opacity(0.95)), lineWidth: 2.2)
    }

    private func drawSubject(_ ctx: inout GraphicsContext, _ size: CGSize, _ m: SubjectMetrics) {
        let rect = CGRect(x: m.box.minX * size.width,
                          y: m.box.minY * size.height,
                          width: m.box.width * size.width,
                          height: m.box.height * size.height)
        guard rect.width > 4, rect.height > 4 else { return }

        ctx.stroke(Path(roundedRect: rect, cornerRadius: 12),
                   with: .color(Theme.amber.opacity(0.92)),
                   style: StrokeStyle(lineWidth: 1.6, dash: [7, 5]))

        // 标签
        let label = m.face != nil ? "人像 \(Int((m.area * 100).rounded()))%"
                                  : "主体 \(Int((m.area * 100).rounded()))%"
        let labelW = CGFloat(label.count) * 7.4 + 12
        let labelX = max(4, min(rect.minX, size.width - labelW - 4))
        let labelY = max(4, rect.minY - 20)
        let labelRect = CGRect(x: labelX, y: labelY, width: labelW, height: 16)
        ctx.fill(Path(roundedRect: labelRect, cornerRadius: 4),
                 with: .color(Theme.amber.opacity(0.92)))
        ctx.draw(Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(red: 0.14, green: 0.10, blue: 0.0)),
                 at: CGPoint(x: labelRect.minX + 6, y: labelRect.midY),
                 anchor: .leading)

        // 质心十字
        let cx = m.centroid.x * size.width
        let cy = m.centroid.y * size.height
        var cross = Path()
        cross.addEllipse(in: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))
        cross.move(to: CGPoint(x: cx - 9, y: cy))
        cross.addLine(to: CGPoint(x: cx - 5.5, y: cy))
        cross.move(to: CGPoint(x: cx + 5.5, y: cy))
        cross.addLine(to: CGPoint(x: cx + 9, y: cy))
        cross.move(to: CGPoint(x: cx, y: cy - 9))
        cross.addLine(to: CGPoint(x: cx, y: cy - 5.5))
        cross.move(to: CGPoint(x: cx, y: cy + 5.5))
        cross.addLine(to: CGPoint(x: cx, y: cy + 9))
        ctx.stroke(cross, with: .color(.white.opacity(0.9)), lineWidth: 1.3)

        // 目标点引导：位置分偏低时，标出最近的构图点
        let placeScore = evaluation.dims.first?.value ?? 100
        if placeScore < 82 {
            var best = CGPoint(x: size.width / 3, y: size.height / 3)
            var bestDist = CGFloat.greatestFiniteMagnitude
            for p in [CGPoint(x: 1.0 / 3, y: 1.0 / 3), CGPoint(x: 2.0 / 3, y: 1.0 / 3),
                      CGPoint(x: 1.0 / 3, y: 2.0 / 3), CGPoint(x: 2.0 / 3, y: 2.0 / 3)] {
                let pt = CGPoint(x: p.x * size.width, y: p.y * size.height)
                let dx = pt.x - cx, dy = pt.y - cy
                let d = (dx * dx + dy * dy).squareRoot()
                if d < bestDist { bestDist = d; best = pt }
            }
            var guide = Path()
            guide.addEllipse(in: CGRect(x: best.x - 11, y: best.y - 11, width: 22, height: 22))
            ctx.stroke(guide, with: .color(Color(red: 0.47, green: 0.90, blue: 1.0).opacity(0.85)),
                       lineWidth: 1.6)

            var link = Path()
            link.move(to: CGPoint(x: cx, y: cy))
            link.addLine(to: best)
            ctx.stroke(link, with: .color(Color(red: 0.47, green: 0.90, blue: 1.0).opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }

    /// 人像引导：眼线 / 头顶标尺 / 视线方向 —— 这些只有关键点才能算准
    private func drawFace(_ ctx: inout GraphicsContext, _ size: CGSize, _ f: FaceInfo) {
        let cyan = Color(red: 0.47, green: 0.90, blue: 1.0)
        let rect = CGRect(x: f.box.minX * size.width,
                          y: f.box.minY * size.height,
                          width: f.box.width * size.width,
                          height: f.box.height * size.height)
        guard rect.width > 8, rect.height > 8 else { return }

        ctx.stroke(Path(roundedRect: rect, cornerRadius: 8),
                   with: .color(cyan.opacity(0.5)),
                   style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        // 眼线 + 双眼
        var eyeY: CGFloat?
        if let l = f.leftEye, let r = f.rightEye {
            let lp = CGPoint(x: l.x * size.width, y: l.y * size.height)
            let rp = CGPoint(x: r.x * size.width, y: r.y * size.height)
            eyeY = (lp.y + rp.y) / 2

            var line = Path()
            line.move(to: lp)
            line.addLine(to: rp)
            ctx.stroke(line, with: .color(cyan.opacity(0.9)), lineWidth: 1.3)

            for p in [lp, rp] {
                var ring = Path()
                ring.addEllipse(in: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
                ctx.stroke(ring, with: .color(.white.opacity(0.95)), lineWidth: 1.4)
                var dot = Path()
                dot.addEllipse(in: CGRect(x: p.x - 1.7, y: p.y - 1.7, width: 3.4, height: 3.4))
                ctx.fill(dot, with: .color(.white))
            }
        }

        // 头顶留白标尺
        let hx = rect.midX
        var bracket = Path()
        bracket.move(to: CGPoint(x: hx, y: 1))
        bracket.addLine(to: CGPoint(x: hx, y: max(1, rect.minY)))
        bracket.move(to: CGPoint(x: hx - 5, y: rect.minY))
        bracket.addLine(to: CGPoint(x: hx + 5, y: rect.minY))
        ctx.stroke(bracket,
                   with: .color(cyan.opacity(f.headroom < 0.02 ? 1 : 0.7)),
                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        if f.headroom > 0.02 {
            let pct = Int((f.headroom * 100).rounded())
            ctx.draw(Text("头顶 \(pct)%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(cyan.opacity(0.92)),
                     at: CGPoint(x: hx + 8, y: max(9, rect.minY / 2)),
                     anchor: .leading)
        }

        // 视线方向
        if abs(f.turn) > 0.18, let nose = f.nose {
            let np = CGPoint(x: nose.x * size.width, y: nose.y * size.height)
            let len = max(24, rect.width * 0.55)
            var arrow = Path()
            arrow.move(to: np)
            arrow.addLine(to: CGPoint(x: np.x + (f.turn > 0 ? len : -len), y: np.y))
            ctx.stroke(arrow,
                       with: .color(cyan.opacity(0.62)),
                       style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        }

        // 眼线偏离上三分线时给出参考线
        if let eyeY = eyeY, abs(eyeY - size.height / 3) > size.height * 0.045 {
            let gy = size.height / 3
            var guide = Path()
            guide.move(to: CGPoint(x: 0, y: gy))
            guide.addLine(to: CGPoint(x: size.width, y: gy))
            ctx.stroke(guide, with: .color(cyan.opacity(0.4)),
                       style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
            ctx.draw(Text("上三分线")
                        .font(.system(size: 8.5))
                        .foregroundColor(cyan.opacity(0.75)),
                     at: CGPoint(x: size.width - 6, y: gy - 9),
                     anchor: .trailing)
        }
    }

    private func drawLevel(_ ctx: inout GraphicsContext, _ size: CGSize) {
        guard let m = metrics, abs(m.tilt) > 1.2 else { return }
        let cx = size.width / 2
        let cy = size.height / 2
        let len = min(size.width, size.height) * 0.22
        let angle = m.tilt * .pi / 180

        var line = Path()
        line.move(to: CGPoint(x: cx - cos(angle) * len, y: cy + sin(angle) * len))
        line.addLine(to: CGPoint(x: cx + cos(angle) * len, y: cy - sin(angle) * len))
        ctx.stroke(line,
                   with: .color(abs(m.tilt) > 3 ? Theme.red.opacity(0.95)
                                                : Theme.amber.opacity(0.95)),
                   lineWidth: 1.6)

        var guide = Path()
        guide.move(to: CGPoint(x: cx - len, y: cy))
        guide.addLine(to: CGPoint(x: cx + len, y: cy))
        ctx.stroke(guide, with: .color(.white.opacity(0.35)),
                   style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
    }
}

//
//  FaceAnalyzer.swift
//  FrameCraft
//
//  Vision 人脸关键点：给"人像构图"补上真正可算的三个量——
//    · 眼线高度（眼睛是否落在上三分线）
//    · 头顶留白（有没有切头发 / 留白过多）
//    · 视线方向与留白（人物看向哪边，那边有没有地方）
//
//  坐标系统一：归一化到"取景可见区"，原点左上，与 OverlayLayer 直接对应。
//

import Foundation
import Vision
import CoreVideo
import UIKit

// MARK: - 人像指标

struct FaceInfo {
    /// 面部包围盒（归一化，左上原点，相对可见区）
    var box: CGRect = .zero
    /// 图像坐标里靠左 / 靠右的眼睛（不是人物自己的左右）
    var leftEye: CGPoint?
    var rightEye: CGPoint?
    var nose: CGPoint?
    var mouth: CGPoint?
    /// 头部滚转（度，正 = 头向画面右侧倾）
    var roll: CGFloat = 0
    /// 视线朝向：-1 看左 … 0 正视 … +1 看右（由鼻尖相对眼中线的偏移推出）
    var turn: CGFloat = 0
    /// 眼睛连线的纵向位置（0 = 画面顶）
    var eyeLineY: CGFloat = 0
    /// 双眼中点横向位置
    var eyeMidX: CGFloat = 0.5
    /// 头顶到画面上沿的距离（以画面高度为单位）
    var headroom: CGFloat = 0
    var confidence: CGFloat = 0
    /// 本帧检测到的人脸数量（群像判断）
    var count: Int = 1

    var hasEyes: Bool { leftEye != nil && rightEye != nil }
    var eyeSpan: CGFloat {
        guard let l = leftEye, let r = rightEye else { return 0 }
        return abs(r.x - l.x)
    }
}

// MARK: - 检测

enum FaceAnalyzer {

    /// 低于此置信度的结果直接丢掉，避免把海报、花纹当成人脸
    static let minConfidence: CGFloat = 0.40
    /// 可见区内最小脸高（相对画面高度），太小的检测不稳定
    static let minFaceHeight: CGFloat = 0.045

    // MARK: 入口

    /// 视频帧：buffer 已被连接旋转到与预览一致的朝向，因此这里用 .up
    static func detect(pixelBuffer: CVPixelBuffer,
                       crop: CGRect,
                       bufferSize: CGSize) -> FaceInfo? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .up, options: [:])
        return perform(handler, crop: crop, bufferSize: bufferSize)
    }

    /// 静态图：调用方保证传入的是 upright 图像（与 FrameAnalyzer 的位图假设一致）
    static func detect(image: UIImage) -> FaceInfo? {
        guard let cg = image.cgImage, cg.width > 8, cg.height > 8 else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        return perform(handler,
                       crop: CGRect(x: 0, y: 0, width: w, height: h),
                       bufferSize: CGSize(width: w, height: h))
    }

    // MARK: 主流程

    private static func perform(_ handler: VNImageRequestHandler,
                               crop: CGRect,
                               bufferSize: CGSize) -> FaceInfo? {
        guard crop.width > 4, crop.height > 4,
              bufferSize.width > 8, bufferSize.height > 8 else { return nil }

        let request = VNDetectFaceLandmarksRequest()
        request.revision = Int(VNDetectFaceLandmarksRequestRevision3)

        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        // Xcode 16 的 SDK 里 request.results 已经是 [VNFaceObservation]?，
        // 再做一次条件转型是空操作（会报 warning），直接绑定即可
        guard let results = request.results, !results.isEmpty else {
            return nil
        }

        let visible = CGRect(x: 0, y: 0, width: 1, height: 1)
        var primaryBox: CGRect?
        var primaryPoints = FacePoints()
        var primaryConfidence: CGFloat = 0
        var primaryRoll: CGFloat = 0
        var count = 0

        for obs in results {
            guard CGFloat(obs.confidence) >= minConfidence else { continue }
            let rect = mapBox(obs.boundingBox, crop: crop, size: bufferSize)
            let clipped = rect.intersection(visible)
            guard !clipped.isNull, clipped.height >= minFaceHeight else { continue }

            count += 1
            let area = rect.width * rect.height
            let bestArea = (primaryBox?.width ?? 0) * (primaryBox?.height ?? 0)
            if primaryBox == nil || area > bestArea {
                primaryBox = rect
                primaryPoints = mapLandmarks(obs, crop: crop, size: bufferSize)
                primaryConfidence = CGFloat(obs.confidence)
                primaryRoll = CGFloat(obs.roll?.doubleValue ?? 0)
            }
        }

        guard count > 0, let rawBox = primaryBox else { return nil }
        let box = rawBox.intersection(visible)
        guard !box.isNull, box.width > 0.01, box.height > 0.01 else { return nil }

        var info = FaceInfo()
        info.box = box
        info.count = count
        info.confidence = primaryConfidence
        info.leftEye = primaryPoints.leftEye
        info.rightEye = primaryPoints.rightEye
        info.nose = primaryPoints.nose
        info.mouth = primaryPoints.mouth
        info.headroom = max(0, box.minY)

        if let l = info.leftEye, let r = info.rightEye, abs(r.x - l.x) > 0.004 {
            info.eyeLineY = (l.y + r.y) / 2
            info.eyeMidX = (l.x + r.x) / 2
            // 眼睛连线相对水平的倾角；归一化坐标下需按宽高比校正
            let dx = (r.x - l.x) * max(1, bufferSize.width / max(1, bufferSize.height))
            let dy = (r.y - l.y)
            info.roll = CGFloat(atan2(Double(dy), Double(dx))) * 180 / .pi
        } else if let one = info.leftEye ?? info.rightEye {
            info.eyeLineY = one.y
            info.eyeMidX = one.x
            info.roll = CGFloat(primaryRoll)
        } else {
            info.eyeLineY = box.midY
            info.eyeMidX = box.midX
            info.roll = CGFloat(primaryRoll)
        }

        if let n = info.nose {
            let width = max(box.width, 0.02)
            let off = (n.x - info.eyeMidX) / width      // 约 -0.5…+0.5
            info.turn = min(max(off / 0.5, -1), 1)
        }

        return info
    }

    // MARK: 坐标映射（Vision 归一化左下原点 → 可见区归一化左上原点）

    private struct FacePoints {
        var leftEye: CGPoint?
        var rightEye: CGPoint?
        var nose: CGPoint?
        var mouth: CGPoint?
    }

    private static func mapBox(_ b: CGRect, crop: CGRect, size: CGSize) -> CGRect {
        let W = size.width, H = size.height
        // 先换成像素（左上原点），再换算到可见区
        let topPx = H - (b.maxY * H)
        return CGRect(x: (b.minX * W - crop.minX) / crop.width,
                      y: (topPx - crop.minY) / crop.height,
                      width: b.width * W / crop.width,
                      height: b.height * H / crop.height)
    }

    private static func mapPoint(_ p: CGPoint, crop: CGRect, size: CGSize) -> CGPoint {
        let W = size.width, H = size.height
        return CGPoint(x: (p.x * W - crop.minX) / crop.width,
                       y: ((H - p.y * H) - crop.minY) / crop.height)
    }

    /// 关键点坐标是相对"人脸包围盒"归一的，需要先还原到图像再映射
    private static func mapLandmarks(_ obs: VNFaceObservation,
                                     crop: CGRect,
                                     size: CGSize) -> FacePoints {
        var out = FacePoints()
        guard let lm = obs.landmarks else { return out }
        let fb = obs.boundingBox

        func region(_ r: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let r = r, r.pointCount > 0 else { return nil }
            let pts = r.normalizedPoints
            guard !pts.isEmpty else { return nil }
            var sx: CGFloat = 0, sy: CGFloat = 0
            for p in pts { sx += p.x; sy += p.y }
            let n = CGFloat(pts.count)
            let inFace = CGPoint(x: fb.minX + (sx / n) * fb.width,
                                 y: fb.minY + (sy / n) * fb.height)
            return mapPoint(inFace, crop: crop, size: size)
        }

        var eyes: [CGPoint] = []
        if let e = region(lm.leftEye) { eyes.append(e) }
        if let e = region(lm.rightEye) { eyes.append(e) }
        if eyes.count == 2 {
            let sorted = eyes.sorted { $0.x < $1.x }
            out.leftEye = sorted[0]
            out.rightEye = sorted[1]
        } else if eyes.count == 1 {
            // 只有一只眼可见（侧脸）：留着位置用，但不参与眼线/滚转计算
            out.leftEye = eyes[0]
        }
        out.nose = region(lm.nose)
        out.mouth = region(lm.outerLips)
        return out
    }
}

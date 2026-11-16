//
//  Support.swift
//  FrameCraft
//
//  主题色 / 图片工具 / 通用小组件 / 相册
//

import SwiftUI
import Photos
import UIKit

// MARK: - 主题

enum Theme {
    static let bg      = Color(red: 0.039, green: 0.043, blue: 0.051)
    static let panel   = Color(red: 0.078, green: 0.086, blue: 0.102)
    static let panel2  = Color(red: 0.106, green: 0.118, blue: 0.137)
    static let amber   = Color(red: 1.000, green: 0.773, blue: 0.239)
    static let green   = Color(red: 0.290, green: 0.870, blue: 0.500)
    static let red     = Color(red: 0.970, green: 0.440, blue: 0.440)
    static let dim     = Color(white: 0.56)
    static let hairline = Color.white.opacity(0.10)

    static func scoreColor(_ v: Int) -> Color {
        v >= 86 ? green : (v >= 70 ? amber : red)
    }
}

// MARK: - 图片工具

extension UIImage {

    /// 烘焙方向，后续裁切都基于 upright 图像
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 居中裁切到指定宽高比（与预览的 resizeAspectFill 一致）
    func centerCropped(to aspect: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        guard w > 0, h > 0, aspect > 0, aspect.isFinite else { return self }
        var cw = w, ch = h
        if w / h > aspect { cw = h * aspect } else { ch = w / aspect }
        return cropped(to: CGRect(x: (w - cw) / 2, y: (h - ch) / 2, width: cw, height: ch))
    }

    /// 等比缩放到指定宽度上限（分析前先缩小，避免几十 MB 的位图）
    func resized(maxWidth: CGFloat) -> UIImage {
        guard size.width > maxWidth, size.width > 0 else { return self }
        let scale = maxWidth / size.width
        let target = CGSize(width: maxWidth, height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    func cropped(to rect: CGRect) -> UIImage {
        guard let cg = cgImage, size.width > 0, size.height > 0 else { return self }
        let sx = CGFloat(cg.width) / size.width
        let sy = CGFloat(cg.height) / size.height
        var px = CGRect(x: rect.minX * sx, y: rect.minY * sy,
                        width: rect.width * sx, height: rect.height * sy).integral
        px = px.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard px.width > 1, px.height > 1, let cut = cg.cropping(to: px) else { return self }
        return UIImage(cgImage: cut, scale: scale, orientation: .up)
    }
}

// MARK: - 按钮手感

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 小组件

struct Chip: View {
    let text: String
    var accent: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(accent ? Theme.amber.opacity(0.16)
                                              : Color.white.opacity(0.10)))
            .overlay(Capsule().stroke(accent ? Theme.amber.opacity(0.35)
                                             : Color.white.opacity(0.09), lineWidth: 1))
            .foregroundColor(accent ? Color(red: 1, green: 0.84, blue: 0.48)
                                    : Color(white: 0.84))
    }
}

struct SmallPill: View {
    let title: String
    var active: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9)
                    .fill(active ? Theme.amber.opacity(0.15) : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(active ? Theme.amber.opacity(0.45) : Theme.hairline, lineWidth: 1))
                .foregroundColor(active ? Theme.amber : Theme.dim)
        }
        .buttonStyle(PressableStyle())
    }
}

struct TipRow: View {
    let text: String
    var ok: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Text(ok ? "✓" : "调")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ok ? Theme.green : Theme.amber)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.88))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.black.opacity(ok ? 0.55 : 0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(ok ? Theme.green.opacity(0.35) : Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

struct ScoreRing: View {
    let score: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, CGFloat(score) / 100)))
                .stroke(Theme.scoreColor(score),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.28), value: score)
            Text(score > 0 ? "\(score)" : "--")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 52, height: 52)
    }
}

// MARK: - 相册

final class AlbumStore: ObservableObject {

    struct Shot: Identifiable {
        let id = UUID()
        let image: UIImage
        let score: Int
        let rule: String
        let date: Date
    }

    @Published var shots: [Shot] = []

    func add(_ image: UIImage, score: Int, rule: String) {
        shots.insert(Shot(image: image, score: score, rule: rule, date: Date()), at: 0)
        if shots.count > 40 { shots.removeLast() }
    }

    /// 写入系统相册（需要 NSPhotoLibraryAddUsageDescription）
    func saveToLibrary(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { ok, _ in
                DispatchQueue.main.async { completion(ok) }
            }
        }
    }
}

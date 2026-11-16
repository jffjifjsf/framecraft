//
//  FilterStrip.swift
//  FrameCraft
//
//  成片滤镜条：场景 / 风格两组，缩略图实时反映当前照片，
//  可切场景、调强度、恢复原图、取消 / 应用
//

import SwiftUI
import UIKit

// MARK: - 分组

enum FilterGroup: String, CaseIterable, Identifiable {
    case scene, style

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scene: return "场景"
        case .style: return "风格"
        }
    }
}

// MARK: - 状态

/// 一张照片的滤镜会话。
/// 只缓存"够用"的量：缩略图全部常驻，预览按 LRU 留最近 3 张，
/// 成片只留最近应用的那一张——避免十几种选择各存一份全尺寸图把内存吃穿。
final class FilterModel: ObservableObject {

    /// 当前显示的选择（＝实时预览，未提交）
    @Published private(set) var choice: FilterChoice = .original
    /// 当前强度，0…1
    @Published private(set) var intensity: Double = 1.0
    /// 面板上正在看的组
    @Published var group: FilterGroup = .scene
    /// 上次在这个设备上用过的场景。只做提示，不自动套用——
    /// 自动套会让人误以为是自己选的，取消时还会以为是"没生效"
    @Published private(set) var lastScene: SceneFilter? = FilterModel.storedLastScene()

    @Published private(set) var preview: UIImage?
    @Published private(set) var thumbnails: [String: UIImage] = [:]

    /// 已提交的选择与强度，取消时整体回退到这一组
    private(set) var applied: FilterChoice = .original
    private(set) var appliedIntensity: Double = 1.0

    private var full: UIImage?          // 原尺寸，导出用
    private var base: UIImage?          // 预览用，限宽 1000
    private var previewCache: [String: UIImage] = [:]
    private var previewOrder: [String] = []

    /// 全尺寸成片只留一张，换选择就作废，避免几十 MB 常驻
    private var fullImage: UIImage?
    private var fullKey: String?

    /// 渲染节流：拖动强度时只保留最新一帧，不让队列积压
    private var renderInFlight = false
    private var renderAgain = false

    private let queue = DispatchQueue(label: "framecraft.filter", qos: .userInitiated)
    private let previewLimit = 3

    // MARK: 装配

    func attach(_ image: UIImage) {
        guard base == nil else { return }
        full = image                        // 先占位，导出永远有图可用

        // 缩放与十几份缩略图都放后台：进诊断页时不能有一下卡顿
        queue.async { [weak self] in
            let upright = image.normalized()
            let small = upright.resized(maxWidth: 1000)
            let source = upright.centerCropped(to: 1).resized(maxWidth: 132)

            var map: [String: UIImage] = [FilterChoice.original.key: source]
            for s in SceneFilter.allCases {
                map[FilterChoice.scene(s).key] = FilterEngine.apply(.scene(s), to: source)
            }
            for f in PhotoFilter.allCases where !f.isIdentity {
                map[FilterChoice.style(f).key] = FilterEngine.apply(.style(f), to: source)
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.full = upright             // 烘焙过方向，导出时按同一套像素走
                self.base = small
                self.preview = small
                self.thumbnails = map

                // 图还没就绪时用户就点了某项：现在补渲染一次
                if !self.choice.isIdentity {
                    let pending = self.choice
                    self.choice = .original
                    self.select(pending)
                }
            }
        }
    }

    // MARK: 选择 / 强度

    func select(_ target: FilterChoice) {
        guard target != choice else { return }
        choice = target
        requestPreview()
    }

    /// 强度的唯一入口。范围在这里夹住，UI 只负责给值
    func setIntensity(_ value: Double) {
        let v = min(max(value, 0), 1)
        guard abs(v - intensity) > 0.001 else { return }
        intensity = v
        requestPreview()
    }

    /// 强度是否可调：原图状态下拧滑块没有意义
    var intensityEnabled: Bool { !choice.isIdentity }

    // MARK: 预览渲染

    private func requestPreview() {
        guard let base = base else { return }

        // 原图 / 强度归零：直接回到未处理的预览，不浪费一次渲染
        if choice.isIdentity || intensity < 0.01 {
            preview = base
            return
        }

        let target = choice
        let strength = intensity
        let key = cacheKey(target, strength)

        if let cached = previewCache[key] {
            touch(key)
            preview = cached
            return
        }

        // 上一帧还没渲染完就先记一笔，等它回来后补最新值——不排队、不积压
        if renderInFlight {
            renderAgain = true
            return
        }
        renderInFlight = true

        queue.async { [weak self] in
            let out = FilterEngine.apply(target, to: base, intensity: strength)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.storePreview(out, for: key)
                self.renderInFlight = false

                // 只有仍是当前选择时才落地，避免旧结果盖掉新选择
                if target == self.choice, abs(strength - self.intensity) < 0.001 {
                    self.preview = out
                }
                if self.renderAgain {
                    self.renderAgain = false
                    self.requestPreview()
                }
            }
        }
    }

    // MARK: 提交

    /// 应用：提交当前选择与强度，并在后台把全尺寸成片先烘焙好
    func applyCurrent() {
        applied = choice
        appliedIntensity = intensity
        fullImage = nil
        fullKey = nil
        remember(choice)

        guard !choice.isIdentity, intensity > 0.01, let full = full else { return }
        let target = choice
        let strength = intensity
        let key = cacheKey(target, strength)

        queue.async { [weak self] in
            let out = FilterEngine.apply(target, to: full, intensity: strength)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.fullImage = out
                self.fullKey = key
            }
        }
    }

    /// 取消：回到进入面板前的状态（选择和强度一起回退）
    func revert() {
        choice = applied
        intensity = appliedIntensity
        requestPreview()
    }

    /// 恢复原图：清掉选择、强度归位，但留在面板里可以继续挑
    func reset() {
        choice = .original
        intensity = 1.0
        preview = base
    }

    /// 导出用图：已应用滤镜则返回烘焙后的成片，否则原样返回
    func exportImage() -> UIImage {
        let source = full ?? UIImage()
        guard !applied.isIdentity, appliedIntensity > 0.01 else { return source }

        let key = cacheKey(applied, appliedIntensity)
        if let cached = fullImage, fullKey == key { return cached }

        let out = FilterEngine.apply(applied, to: source, intensity: appliedIntensity)
        fullImage = out
        fullKey = key
        return out
    }

    // MARK: 记忆

    private static let lastSceneKey = "framecraft.lastSceneFilter"

    private static func storedLastScene() -> SceneFilter? {
        guard let raw = UserDefaults.standard.string(forKey: lastSceneKey) else { return nil }
        return SceneFilter(rawValue: raw)
    }

    /// 只记场景，不记风格：场景和拍摄对象强相关，会稳定复用；
    /// 风格是个人口味，每次都想换
    private func remember(_ choice: FilterChoice) {
        guard case .scene(let scene) = choice else { return }
        UserDefaults.standard.set(scene.rawValue, forKey: FilterModel.lastSceneKey)
        lastScene = scene
    }

    // MARK: 缓存

    /// 强度量化到 5% 一档：缓存不会因为滑块每一像素变化而膨胀，
    /// 而 5% 的差异在屏幕上根本看不出来
    private func cacheKey(_ choice: FilterChoice, _ strength: Double) -> String {
        "\(choice.key)@\(Int((strength * 20).rounded()))"
    }

    private func storePreview(_ image: UIImage, for key: String) {
        previewCache[key] = image
        touch(key)
        while previewOrder.count > previewLimit, let oldest = previewOrder.first {
            previewOrder.removeFirst()
            previewCache.removeValue(forKey: oldest)
        }
    }

    private func touch(_ key: String) {
        previewOrder.removeAll { $0 == key }
        previewOrder.append(key)
    }
}

// MARK: - 滤镜条

struct FilterStrip: View {

    @ObservedObject var model: FilterModel
    /// 当前照片被判定成的场景，只做角标提示，不替用户自动选
    let recommended: SceneFilter?
    let onCancel: () -> Void
    let onReset: () -> Void
    let onApply: () -> Void

    @Environment(\.verticalSizeClass) private var vSize

    private var compact: Bool { vSize == .compact }
    private var thumbSize: CGFloat { compact ? 46 : 58 }

    var body: some View {
        VStack(spacing: compact ? 6 : 8) {
            topBar
            strip
            intensityRow
            actionRow
        }
        .padding(.top, compact ? 7 : 9)
        .padding(.bottom, 6)
        .background(Color(red: 0.062, green: 0.070, blue: 0.082))
        .overlay(Rectangle().fill(Theme.hairline).frame(height: 1), alignment: .top)
    }

    // MARK: 顶部：分组切换 + 当前说明

    private var topBar: some View {
        HStack(spacing: 7) {
            ForEach(FilterGroup.allCases) { g in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { model.group = g }
                } label: {
                    Text(g.label)
                        .font(.system(size: 11, weight: model.group == g ? .semibold : .regular))
                        .foregroundColor(model.group == g ? Theme.amber : Color(white: 0.60))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(model.group == g
                                                   ? Theme.amber.opacity(0.16)
                                                   : Color.white.opacity(0.06)))
                        .overlay(Capsule().stroke(model.group == g
                                                  ? Theme.amber.opacity(0.45)
                                                  : Color.clear, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }

            if !compact {
                Text(hintText)
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(white: 0.58))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    /// 还没选的时候提一句上次用的——比在格子上画个没人看得懂的环更直白。
    /// 顶栏横向空间有限，文案必须短
    private var hintText: String {
        if model.choice.isIdentity, let last = model.lastScene {
            return "上次用的是「\(last.label)」"
        }
        return model.choice.hint
    }

    // MARK: 缩略图

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                switch model.group {
                case .scene:
                    FilterCell(choice: .original,
                               thumb: model.thumbnails[FilterChoice.original.key],
                               selected: model.choice == .original,
                               recommended: false,
                               size: thumbSize) {
                        model.select(.original)
                    }
                    ForEach(SceneFilter.allCases) { s in
                        FilterCell(choice: .scene(s),
                                   thumb: model.thumbnails[FilterChoice.scene(s).key],
                                   selected: model.choice == .scene(s),
                                   recommended: recommended == s,
                                   size: thumbSize,
                                   lastUsed: model.lastScene == s) {
                            model.select(.scene(s))
                        }
                    }
                case .style:
                    ForEach(PhotoFilter.allCases) { f in
                        FilterCell(choice: FilterChoice.from(style: f),
                                   thumb: model.thumbnails[FilterChoice.from(style: f).key],
                                   selected: model.choice == FilterChoice.from(style: f),
                                   recommended: false,
                                   size: thumbSize) {
                            model.select(FilterChoice.from(style: f))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 1)
        }
        .frame(height: thumbSize + (compact ? 18 : 21))
    }

    // MARK: 强度

    private var intensityRow: some View {
        HStack(spacing: 10) {
            Text("强度")
                .font(.system(size: 10.5))
                .foregroundColor(model.intensityEnabled ? Theme.dim : Color(white: 0.32))

            Slider(value: Binding(get: { model.intensity },
                                  set: { model.setIntensity($0) }),
                   in: 0...1)
                .tint(Theme.amber)
                .disabled(!model.intensityEnabled)

            Text(model.intensityEnabled
                 ? "\(Int((model.intensity * 100).rounded()))%"
                 : "—")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(model.intensityEnabled ? Theme.amber : Color(white: 0.32))
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 22)
    }

    // MARK: 三键

    private var actionRow: some View {
        HStack(spacing: 10) {
            actionButton("取消", fill: Theme.panel2,
                         foreground: Color(white: 0.88), weight: .semibold,
                         action: onCancel)
            actionButton("恢复原图", fill: Theme.panel2,
                         foreground: Color(white: 0.88), weight: .semibold,
                         action: onReset)
            actionButton("应用", fill: Theme.amber,
                         foreground: Color(red: 0.10, green: 0.08, blue: 0.02), weight: .bold,
                         action: onApply)
        }
        .padding(.horizontal, 16)
    }

    private func actionButton(_ title: String,
                              fill: Color,
                              foreground: Color,
                              weight: Font.Weight,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: weight))
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(fill))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - 单个滤镜

struct FilterCell: View {

    let choice: FilterChoice
    let thumb: UIImage?
    let selected: Bool
    /// 这个场景和当前照片匹配，给个角标提示
    let recommended: Bool
    let size: CGFloat
    /// 上次用过的场景：加一圈虚线环（和蓝色的"匹配推荐"是两回事）
    var lastUsed: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Theme.panel2)
                    if let thumb = thumb {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipped()
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(selected ? Theme.amber : Theme.hairline,
                                lineWidth: selected ? 1.8 : 1)
                )
                // 上次用过的：向外扩一圈虚线，不占用缩略图本身
                .overlay {
                    if lastUsed && !selected {
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(Color.white.opacity(0.30),
                                          style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .padding(-3.5)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(Color(red: 0.14, green: 0.10, blue: 0.0))
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Theme.amber))
                            .padding(3)
                    } else if recommended {
                        Circle()
                            .fill(Color(red: 0.42, green: 0.78, blue: 1.0))
                            .frame(width: 6, height: 6)
                            .padding(5)
                    }
                }

                Text(choice.label)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? Theme.amber : Color(white: 0.62))
                    .lineLimit(1)
            }
            .frame(width: size + 4)
        }
        .buttonStyle(PressableStyle())
    }
}

//
//  ReviewView.swift
//  FrameCraft
//
//  拍后诊断：原图 vs 建议构图 拖动对比 + 六维分项 + 重拍建议 + 成片滤镜
//

import SwiftUI

struct ReviewView: View {

    let payload: ReviewPayload
    let onRetake: () -> Void
    let onKeep: (UIImage, Evaluation) -> Void
    let onSaveToLibrary: (UIImage) -> Void

    @State private var split: CGFloat = 0.5
    @State private var isDragging = false

    // 滤镜：只作用在右侧"成片"，左侧原图保持拍摄时的样子
    @StateObject private var filters = FilterModel()
    @State private var showFilters = false

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header(proxy: proxy)
                ScrollView {
                    VStack(spacing: 14) {
                        compareCard
                            .id("compare")
                        scoreDelta
                        barsCard
                        tipsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                if showFilters {
                    FilterStrip(model: filters,
                                recommended: recommendedScene,
                                onCancel: {
                                    filters.revert()
                                    withAnimation(.easeOut(duration: 0.2)) { showFilters = false }
                                },
                                onReset: {
                                    filters.reset()
                                },
                                onApply: {
                                    filters.applyCurrent()
                                    withAnimation(.easeOut(duration: 0.2)) { showFilters = false }
                                })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                // 面板打开时收起底部三键，避免"看到的是预览、导出的是旧值"这种错配
                if !showFilters {
                    footer
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.22), value: showFilters)
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { filters.attach(payload.reframed) }
    }

    // MARK: 顶部

    private func header(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 10) {
            Button(action: onRetake) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(white: 0.82))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(PressableStyle())

            Text("拍后诊断")
                .font(.system(size: 14.5, weight: .semibold))

            Spacer()

            Button { toggleFilters(proxy) } label: {
                Image(systemName: "camera.filters")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(showFilters ? Theme.amber : Color(white: 0.82))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(showFilters ? Theme.amber.opacity(0.16)
                                                          : Color.white.opacity(0.08)))
            }
            .buttonStyle(PressableStyle())

            Chip(text: payload.after.rule, accent: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(Rectangle().fill(Theme.hairline).frame(height: 1), alignment: .bottom)
    }

    /// 面板展开时把对比图顶回视野——不然边调滤镜边看不到效果
    private func toggleFilters(_ proxy: ScrollViewProxy) {
        if showFilters {
            filters.revert()                       // 再点一次等于取消
            withAnimation(.easeOut(duration: 0.2)) { showFilters = false }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { showFilters = true }
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.26)) { proxy.scrollTo("compare", anchor: .top) }
            }
        }
    }

    // MARK: 对比

    private var compareCard: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let x = min(max(w * split, 0), w)

            ZStack(alignment: .leading) {
                Image(uiImage: payload.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: w, height: h)

                Image(uiImage: filters.preview ?? payload.reframed)
                    .resizable()
                    .scaledToFit()
                    .frame(width: w, height: h)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: x)
                    }

                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 1.5, height: h)
                    .offset(x: x - 0.75)
                    .shadow(color: .black.opacity(0.35), radius: 2)

                // 用 position 而不是 offset：ZStack 的垂直方向本来就居中排布，
                // 再叠一次 y 位移会把把手直接推到卡片下沿外面
                splitHandle
                    .scaleEffect(isDragging ? 1.12 : 1)
                    .position(x: x, y: h / 2)

                VStack {
                    HStack {
                        tag("拍摄原图", accent: false)
                        Spacer()
                        tag(rightTagText, accent: true)
                    }
                    Spacer()
                }
                .padding(8)
                // 拖动时把标签压淡：手指划过的那一带不该被文字挡住
                .opacity(isDragging ? 0.28 : 1)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            withAnimation(.easeOut(duration: 0.12)) { isDragging = true }
                        }
                        split = min(max(value.location.x / max(1, w), 0.02), 0.98)
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.18)) { isDragging = false }
                    }
            )
        }
        .aspectRatio(payload.cropAspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var splitHandle: some View {
        ZStack {
            Circle().fill(Color.white).frame(width: 30, height: 30)
            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(Color(white: 0.15))
        }
        .shadow(color: .black.opacity(0.4), radius: 4)
    }

    /// 右侧标签跟着滤镜走：让用户一眼知道这一侧是"调过色的成片"，
    /// 强度不是满格时一并标出来，避免误以为看到的就是最终成片
    private var rightTagText: String {
        guard !filters.choice.isIdentity else { return "建议构图" }
        let pct = Int((filters.intensity * 100).rounded())
        return pct < 99 ? "成片 · \(filters.choice.label) \(pct)%"
                        : "成片 · \(filters.choice.label)"
    }

    /// 照片被判定成人像时，只在「人像」格子上点个提示，不替用户自动选
    private var recommendedScene: SceneFilter? {
        payload.after.scene.contains("人像") ? .portrait : nil
    }

    private func tag(_ text: String, accent: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(accent ? Theme.amber.opacity(0.22) : Color.black.opacity(0.6)))
            .foregroundColor(accent ? Color(red: 1, green: 0.84, blue: 0.48) : Color(white: 0.86))
    }

    // MARK: 分数变化

    private var scoreDelta: some View {
        HStack(spacing: 12) {
            scoreBox(title: "原图构图分", value: payload.before.total, highlighted: false)
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.dim)
            scoreBox(title: "重构后", value: payload.after.total, highlighted: true)
        }
    }

    private func scoreBox(title: String, value: Int, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(Theme.dim)
            Text("\(value)")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundColor(highlighted ? Theme.scoreColor(value) : Color(white: 0.86))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel2))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
    }

    // MARK: 分项

    private var barsCard: some View {
        VStack(spacing: 9) {
            ForEach(payload.after.dims) { dim in
                let before = payload.before.dims.first(where: { $0.name == dim.name })?.value ?? 0
                VStack(spacing: 4) {
                    HStack {
                        Text(dim.name)
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.72))
                        Spacer()
                        Text("\(Int(before.rounded())) → \(Int(dim.value.rounded()))")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(Theme.dim)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(Theme.scoreColor(Int(dim.value.rounded())))
                                .frame(width: g.size.width * min(max(dim.value, 0), 100) / 100)
                            Rectangle()
                                .fill(Color.white.opacity(0.55))
                                .frame(width: 2)
                                .offset(x: max(0, g.size.width * min(max(before, 0), 100) / 100 - 1))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
    }

    // MARK: 建议

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("重拍建议")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.dim)

            if payload.after.tips.isEmpty {
                TipRow(text: "这张已经成立。下次想更进一步：改变机位高度，试试更强的透视感。", ok: true)
            } else {
                ForEach(Array(payload.after.tips.prefix(3))) { tip in
                    let order = (payload.after.tips.firstIndex(where: { $0.id == tip.id }) ?? 0) + 1
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(order)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.dim)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                        Text(tip.text)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.86))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Theme.panel2))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
    }

    // MARK: 底部

    private var footer: some View {
        HStack(spacing: 10) {
            Button(action: onRetake) {
                Text("重拍")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color(white: 0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel2))
            }
            .buttonStyle(PressableStyle())

            Button { onSaveToLibrary(filters.exportImage()) } label: {
                Text("存储")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color(white: 0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel2))
            }
            .buttonStyle(PressableStyle())

            Button { onKeep(filters.exportImage(), payload.after) } label: {
                Text("保留")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(Color(red: 0.10, green: 0.08, blue: 0.02))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.amber))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.panel)
    }
}

// MARK: - 相册

struct AlbumView: View {

    @ObservedObject var album: AlbumStore
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        NavigationStack {
            Group {
                if album.shots.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 34))
                            .foregroundColor(Theme.dim)
                        Text("相册还是空的，先拍一张")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.dim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(album.shots) { shot in
                                ZStack(alignment: .bottomLeading) {
                                    Image(uiImage: shot.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 132)
                                        .clipped()
                                    Text("\(shot.score)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.black.opacity(0.65)))
                                        .foregroundColor(Theme.scoreColor(shot.score))
                                        .padding(6)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(10)
                    }
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("相册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(Theme.amber)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

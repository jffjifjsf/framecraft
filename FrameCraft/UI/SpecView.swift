//
//  SpecView.swift
//  FrameCraft
//
//  设计说明（保留 Web 原型中的产品定义，便于交付评审）
//

import SwiftUI

struct SpecView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("一句话定位",
                            "把构图常识变成取景时看得见的目标点和一句可执行的话，而不是拍完靠裁切补救。")

                    block("功能边界", [
                        ("做", "取景期实时构图判定 · 三分/黄金/中心/对称 · 主体识别与位置框 · 人脸关键点（眼线/头顶留白/视线） · 比例切换与智能裁剪 · 拍后原图对比建议构图 · 六维（人像七维）评分与重拍建议 · 成片调色（6 种拍摄场景 + 9 种风格，可调强度，支持预览 / 应用 / 取消 / 恢复原图）"),
                        ("不做", "磨皮、液化、局部蒙版等精修 · 云端账号与社交 · RAW 与多帧合成 · 精确骨骼姿态 · 替用户自动按快门")
                    ])

                    block("用户流程", [
                        ("1", "打开即取景，默认 4:5 + 三分线 + 智能裁剪开"),
                        ("2", "取景：主体框 / 评分环 / 目标点圈 / 一句主建议"),
                        ("3", "快门：白闪反馈，冻结一帧进诊断"),
                        ("4", "判定：拖动分割线对比，看分项与三条重拍建议"),
                        ("5", "调色：点右上角滤镜图标，右侧成片实时变化"),
                        ("6", "出口：保留（带已应用滤镜）入相册，或重拍")
                    ])

                    block("技术实现", [
                        ("采集", "AVCaptureSession + AVCaptureVideoDataOutput（32BGRA），10fps 节流分析"),
                        ("分析", "降采样 168px → Sobel 边缘 + 大尺度局部均值背景差 + 肤色 → 显著度 → 密度化 → 中心周边抑制"),
                        ("识别", "积分图多尺度窗口搜索（均值×质量占比）→ 窗口内收缩 → 平方加权质心 → 高位像素紧致框"),
                        ("人像", "Vision 人脸关键点：眼线位置 / 头顶留白 / 鼻尖偏移推视线朝向，错帧检测 + 帧间复用"),
                        ("评分", "位置/占比/水平/干净/留白/平衡 六维；检测到人脸时改为七维（人像 26%），非人像场景权重不变"),
                        ("裁剪", "目标比例内接框 → 主体吸附三分位 → 按源坐标重采样"),
                        ("滤镜", "Core Image 固定链路，场景与风格互斥不叠加；强度用结果图与原图按比例溶解，暗角这类无法插参的链路也能正确减弱"),
                        ("场景", "色调曲线定暗部/高光落点 → 通道增益定冷暖 → 饱和对比 → 锐化或暗角；曲线用三个采样点给值，方向由数值决定")
                    ])

                    block("场景滤镜", SceneFilter.allCases.map { ($0.label, $0.detail) })

                    block("已知限制", [
                        ("启发式", "主体识别基于显著度，不是语义分割；纯色背景下多主体会并成一组"),
                        ("人脸", "关键点来自 Vision，侧脸/遮挡时退化为仅用面部框；头顶留白以面部框上沿为基准，比真实发际线略保守"),
                        ("倾斜", "倾斜角来自边缘梯度统计，画面无强水平线时读数不可靠"),
                        ("评分", "经验模型，只用于同一场景不同机位的横向比较，不是美学判决"),
                        ("滤镜", "场景是经验预设，不等于自动白平衡；调色只作用于成片，构图评分始终基于未调色的像素")
                    ])

                    Text("FrameCraft · 原生 iOS\nAVFoundation + Vision 人脸关键点 + 自研构图引擎")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.dim)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("设计说明")
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

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.amber)
                .textCase(.uppercase)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundColor(Color(white: 0.74))
                .lineSpacing(4)
        }
    }

    private func block(_ title: String, _ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.amber)
                .textCase(.uppercase)
            ForEach(rows.indices, id: \.self) { i in
                let row = rows[i]
                HStack(alignment: .top, spacing: 8) {
                    Text(row.0)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(white: 0.72))
                        .frame(width: 34, alignment: .leading)
                    Text(row.1)
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.62))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

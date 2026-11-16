//
//  Models.swift
//  FrameCraft
//
//  构图数据模型 + 规则引擎（与 Web 原型同一套算法与权重）
//

import Foundation
import CoreGraphics

// MARK: - 画面指标（全部归一化到 0...1）

struct SubjectMetrics {
    var box: CGRect = .zero            // 主体包围盒
    var centroid: CGPoint = .init(x: 0.5, y: 0.5)
    var area: CGFloat = 0              // 包围盒面积占比
    var skinRatio: CGFloat = 0         // 肤色像素占比 → 判断人像
    var symmetry: CGFloat = 0          // 左右对称度
    var symAxis: CGFloat = 0.5         // 对称轴位置
    var tilt: CGFloat = 0              // 水平倾斜（度）
    var horizonY: CGFloat = 0.5        // 地平线高度
    var clutter: CGFloat = 0           // 边缘干扰（0 干净 / 1 很乱）
    var balanceLR: CGFloat = 0         // -1 左重 … +1 右重
    var balanceTB: CGFloat = 0
    var confidence: CGFloat = 1
    var peak: CGFloat = 0              // 显著度峰值，用于判断"是否真有主体"
    var face: FaceInfo? = nil          // 人脸关键点（Vision），无人脸时为 nil

    /// 前置摄像头：预览是镜像的，指标必须同步镜像，否则叠加层指反方向
    func mirrored() -> SubjectMetrics {
        var m = self
        m.box = CGRect(x: 1 - box.maxX, y: box.minY,
                       width: box.width, height: box.height)
        m.centroid = CGPoint(x: 1 - centroid.x, y: centroid.y)
        m.symAxis = 1 - symAxis
        m.balanceLR = -balanceLR

        if var f = face {
            f.box = CGRect(x: 1 - f.box.maxX, y: f.box.minY,
                           width: f.box.width, height: f.box.height)
            f.leftEye = f.leftEye.map { CGPoint(x: 1 - $0.x, y: $0.y) }
            f.rightEye = f.rightEye.map { CGPoint(x: 1 - $0.x, y: $0.y) }
            // 镜像后左右眼互换，保证 leftEye.x < rightEye.x
            if let a = f.leftEye, let b = f.rightEye {
                f.leftEye = a.x <= b.x ? a : b
                f.rightEye = a.x <= b.x ? b : a
            }
            f.nose = f.nose.map { CGPoint(x: 1 - $0.x, y: $0.y) }
            f.mouth = f.mouth.map { CGPoint(x: 1 - $0.x, y: $0.y) }
            f.eyeMidX = 1 - f.eyeMidX
            f.roll = -f.roll
            f.turn = -f.turn
            m.face = f
        }
        return m
    }
}

// MARK: - 评分结果

struct DimScore: Identifiable {
    let id = UUID()
    let name: String
    let value: CGFloat
}

struct Suggestion: Identifiable {
    let id = UUID()
    let key: String
    let score: CGFloat
    let text: String
}

struct Evaluation {
    var total: Int = 0
    var verdict: String = ""
    var rule: String = "三分"
    var scene: String = "场景"
    var dims: [DimScore] = []
    var tips: [Suggestion] = []

    static let empty = Evaluation(total: 0, verdict: "正在校准画面…", rule: "三分",
                                  scene: "场景", dims: [], tips: [])
}

// MARK: - 构图选项

enum GridMode: String, CaseIterable {
    case thirds, golden, center, sym, off

    var label: String {
        switch self {
        case .thirds: return "三分线"
        case .golden: return "黄金"
        case .center: return "中心"
        case .sym:    return "对称"
        case .off:    return "关闭"
        }
    }

    var next: GridMode {
        let all = GridMode.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}

struct AspectOption: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: CGFloat
}

enum AspectPreset {
    static let all: [AspectOption] = [
        AspectOption(label: "1:1",  value: 1.0),
        AspectOption(label: "4:5",  value: 0.8),
        AspectOption(label: "3:4",  value: 0.75),
        AspectOption(label: "9:16", value: 0.5625),
        AspectOption(label: "16:9", value: 1.7778)
    ]
}

// MARK: - 规则引擎

enum CompositionEngine {

    private static func clamp100(_ v: CGFloat) -> CGFloat { min(max(v, 0), 100) }

    static func evaluate(_ m: SubjectMetrics) -> Evaluation {
        let cx = m.centroid.x
        let cy = m.centroid.y

        // 检测到人脸时，构图锚点改用"眼睛"——人像的视觉重心是眼线，不是显著度框的质心
        let face = m.face
        let px = face.map { $0.eyeMidX } ?? cx
        let py = face.map { $0.eyeLineY } ?? cy

        // ① 主体位置：三分线 / 居中 / 黄金分割，取最优一项
        let dVert = min(abs(px - 1.0 / 3.0), abs(px - 2.0 / 3.0))
        let dHorz = min(abs(py - 1.0 / 3.0), abs(py - 2.0 / 3.0))
        // 非人像沿用旧规则（只要一个轴到位）；人像要求两个轴都别太离谱，
        // 否则"眼线在上三分线上、但人贴到画面左边缘"会被判满分
        var dPlace = face == nil
            ? min(dVert, dHorz)
            : 0.55 * min(dVert, dHorz) + 0.45 * max(dVert, dHorz)
        var rule = "三分"

        let dxC = px - 0.5, dyC = py - 0.5
        let dCenter = (dxC * dxC + dyC * dyC).squareRoot()

        var dGold: CGFloat = 9
        let goldenPts: [(CGFloat, CGFloat)] = [(0.382, 0.382), (0.618, 0.382),
                                               (0.382, 0.618), (0.618, 0.618)]
        for p in goldenPts {
            let dx = px - p.0, dy = py - p.1
            dGold = min(dGold, (dx * dx + dy * dy).squareRoot())
        }

        if dCenter < dPlace - 0.05 && m.symmetry > 0.55 {
            rule = "居中"
            dPlace = dCenter * 0.95
        } else if dGold < dPlace - 0.02 {
            rule = "黄金分割"
            dPlace = dGold * 1.05
        }

        let sPlace = clamp100(100 - max(0, dPlace) * 300)

        // ② 主体占比：面积 20% 左右最理想
        let area = max(m.area, 0.0001)
        let ratio = CGFloat(log(Double(area / 0.20))) / CGFloat(log(3.2))
        let sSize = clamp100(100 - 55 * abs(ratio))

        // ③ 水平
        let sLevel = clamp100(100 - abs(m.tilt) * 9)

        // ④ 画面干净
        let sClean = clamp100(100 - m.clutter * 170)

        // ⑤ 留白呼吸
        let margin = min(min(m.box.minX, 1 - m.box.maxX),
                         min(m.box.minY, 1 - m.box.maxY))
        let sBreath = clamp100(margin * 640)

        // ⑥ 视觉平衡
        let sBal = clamp100(100 - abs(m.balanceLR) * 70 - abs(m.balanceTB) * 45
                            + (m.symmetry > 0.7 ? 12 : 0))

        // ⑦ 人像三维：眼线 / 头顶留白 / 视线方向（仅在人脸关键点可用时启用）
        var sEye: CGFloat = 0, sHead: CGFloat = 0, sGaze: CGFloat = 0
        var sPortrait: CGFloat = 0
        let hasPortrait = face != nil
        if let f = face {
            // 眼线：理想落在上三分线，黄金分割位也算合格
            let dEye = min(abs(f.eyeLineY - 1.0 / 3.0), abs(f.eyeLineY - 0.382))
            sEye = clamp100(100 - max(0, dEye - 0.015) * 420)

            // 头顶留白：5%~8% 最舒服，贴边会切头发，过多则显空
            let hr = f.headroom
            sHead = clamp100(100 - abs(hr - 0.06) * 420)
            if hr < 0.015 { sHead = min(sHead, 40) }
            else if hr > 0.26 { sHead = min(sHead, 55) }

            // 视线留白：看向哪边，那边就该有空间（全侧脸约需要 40% 的引出空间）
            if abs(f.turn) > 0.18 {
                let space = f.turn > 0 ? (1 - f.box.maxX) : f.box.minX
                let need = 0.10 + abs(f.turn) * 0.30
                sGaze = clamp100(100 - max(0, need - space) * 460)
            } else {
                sGaze = 100          // 正视镜头不需要额外留白
            }

            sPortrait = clamp100(0.40 * sEye + 0.34 * sHead + 0.26 * sGaze)
        }

        // 加权总分：无人脸时权重与旧版完全一致，保证非人像场景评分不变
        var total: CGFloat
        if hasPortrait {
            total = sPlace * 0.22 + sSize * 0.14 + sLevel * 0.10 + sClean * 0.10
                  + sBreath * 0.08 + sBal * 0.10 + sPortrait * 0.26
        } else {
            total = sPlace * 0.28 + sSize * 0.18 + sLevel * 0.14
                  + sClean * 0.14 + sBreath * 0.12 + sBal * 0.14
        }
        total = total.rounded()
        if m.confidence < 1 {
            total = (total * 0.55 + 45 * 0.45).rounded()
        }

        // 建议：按短板排序
        var tips: [Suggestion] = []
        let pct = Int((m.area * 100).rounded())

        if sPlace < 80 {
            var text: String
            if px < 0.42 {
                text = "主体偏左 —— 向右挪半步（或机位右移），让它落到右三分线"
            } else if px > 0.58 {
                text = "主体偏右 —— 向左挪半步（或机位左移），让它落到左三分线"
            } else if py < 0.42 {
                text = "主体偏高 —— 压低机位或后退半步，把主体放到下三分线"
            } else {
                text = "主体偏低 —— 抬高机位，把它放到上三分线，头顶多留空间"
            }
            tips.append(Suggestion(key: "position", score: sPlace, text: text))
        }

        if sSize < 72 {
            let text = m.area < 0.12
                ? "主体仅占 \(pct)%，走近一步或拉近焦段，让主体撑起画面"
                : "主体占 \(pct)%，退后半步留出呼吸空间"
            tips.append(Suggestion(key: "size", score: sSize, text: text))
        }

        if sLevel < 82 {
            let t = String(format: "%.1f", Double(abs(m.tilt)))
            tips.append(Suggestion(key: "level", score: sLevel,
                                   text: "地平线/水平边缘倾斜 \(t)°，先校正机身再构图"))
        }

        if sClean < 74 {
            tips.append(Suggestion(key: "clean", score: sClean,
                                   text: "画面边缘有干扰物，侧移一步换个角度，把杂质挡在画外"))
        }

        if sBreath < 72 {
            tips.append(Suggestion(key: "breath", score: sBreath,
                                   text: "主体贴边了 —— 退半步，让顶部与侧边留出空白"))
        }

        if sBal < 72 {
            let text: String
            if abs(m.balanceLR) > 0.18 {
                text = m.balanceLR > 0
                    ? "画面左侧偏重 —— 机位向右微移配平"
                    : "画面右侧偏重 —— 机位向左微移配平"
            } else {
                text = "上下重心失衡 —— 压低机位或换一个地平线高度"
            }
            tips.append(Suggestion(key: "balance", score: sBal, text: text))
        }

        if m.horizonY > 0.44 && m.horizonY < 0.56 {
            tips.append(Suggestion(key: "horizon", score: 58,
                                   text: "地平线压在画面正中，抬高或压低机位，让它落在三分线上更稳"))
        }

        // 人像专属建议（有脸才出）
        if let f = face {
            if sEye < 80 {
                let eyePct = Int((f.eyeLineY * 100).rounded())
                let text: String
                if f.eyeLineY > 1.0 / 3.0 + 0.04 {
                    text = "眼线落在 \(eyePct)% 偏低 —— 抬高机位，或让被拍者微抬下巴，把眼睛送到上三分线"
                } else {
                    text = "眼线在 \(eyePct)% 偏高 —— 略微降低机位，头顶会自然松开"
                }
                tips.append(Suggestion(key: "eyeLine", score: sEye, text: text))
            }

            if sHead < 78 {
                let text: String
                if f.headroom < 0.02 {
                    text = "头顶贴到画面上沿了 —— 退半步或抬高机位，别把发丝切掉"
                } else {
                    let hrPct = Int((f.headroom * 100).rounded())
                    text = "头顶留白 \(hrPct)% 偏多 —— 走近一步或压低机位，让人物撑满画面"
                }
                tips.append(Suggestion(key: "headroom", score: sHead, text: text))
            }

            if sGaze < 78 {
                let spacePct = Int(((f.turn > 0 ? 1 - f.box.maxX : f.box.minX) * 100).rounded())
                let text = f.turn > 0
                    ? "人物看向右侧，右边只剩 \(spacePct)% 空间 —— 机位往右挪，把视线方向留出来"
                    : "人物看向左侧，左边只剩 \(spacePct)% 空间 —— 机位往左挪，把视线方向留出来"
                tips.append(Suggestion(key: "gaze", score: sGaze, text: text))
            }
        }

        tips.sort { $0.score < $1.score }

        let verdict: String
        if m.confidence < 1 {
            verdict = "画面缺少明确主体，先找出你要拍的对象"
        } else if total >= 86 {
            verdict = "构图成立，可以按快门"
        } else if total >= 72 {
            verdict = "接近了，再微调一步"
        } else if total >= 55 {
            verdict = "画面还没立住，按建议调整"
        } else {
            verdict = "先稳住主体，再谈构图"
        }

        let scene: String
        if let f = face {
            scene = f.count > 1 ? "群像" : "人像"
        } else if m.skinRatio > 0.045 {
            scene = "人像写真"
        } else if m.symmetry > 0.72 {
            scene = "对称场景"
        } else {
            scene = "场景"
        }

        var dims: [DimScore] = [
            DimScore(name: "主体位置", value: sPlace),
            DimScore(name: "主体占比", value: sSize),
            DimScore(name: "水平",     value: sLevel),
            DimScore(name: "画面干净", value: sClean),
            DimScore(name: "留白呼吸", value: sBreath),
            DimScore(name: "视觉平衡", value: sBal)
        ]
        if hasPortrait {
            dims.append(DimScore(name: "人像细节", value: sPortrait))
        }

        return Evaluation(
            total: Int(total),
            verdict: verdict,
            rule: rule,
            scene: scene,
            dims: dims,
            tips: tips
        )
    }

    // MARK: 裁剪建议

    /// 目标比例下能放下的最大内接框
    static func fitAspect(size: CGSize, aspect: CGFloat) -> CGRect {
        if size.width / size.height > aspect {
            let h = size.height
            let w = h * aspect
            return CGRect(x: (size.width - w) / 2, y: 0, width: w, height: h)
        } else {
            let w = size.width
            let h = w / aspect
            return CGRect(x: 0, y: (size.height - h) / 2, width: w, height: h)
        }
    }

    /// 智能裁剪：主体偏小时裁紧，并把构图锚点吸附到三分位
    /// 有脸时锚点是"眼线"——与评分用的是同一个参考点，否则会出现评分说偏、裁剪却按质心走
    static func suggestCrop(size: CGSize, aspect: CGFloat,
                            metrics: SubjectMetrics?, smart: Bool) -> CGRect {
        let base = fitAspect(size: size, aspect: aspect)
        guard smart, let m = metrics else { return base }

        var w = base.width
        var h = base.height
        if m.area < 0.14 { w *= 0.84; h *= 0.84 }

        let face = m.face
        let ax = (face?.eyeMidX ?? m.centroid.x) * size.width
        let ay = (face?.eyeLineY ?? m.centroid.y) * size.height

        // 人像把眼线放到上三分线；其它场景维持原来的 0.40
        let ty = face != nil ? h / 3 : h * 0.40
        let tx = ax < size.width / 2 ? w / 3 : w * 2 / 3

        let x = min(max(ax - tx, 0), size.width - w)
        let y = min(max(ay - ty, 0), size.height - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

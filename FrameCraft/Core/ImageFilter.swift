//
//  ImageFilter.swift
//  FrameCraft
//
//  成片调色：6 种拍摄场景 + 9 种风格，均可调强度；Core Image 链路，无第三方依赖
//
//  场景和风格是两件事，不合并：
//    · 场景解决"这个题材容易拍砸的地方"——校正型，参数克制，目标是还原现场该有的样子
//    · 风格决定"这张照片想给人什么感觉"——表达型，允许夸张，比如黑白、暗角
//  两者互斥使用：同一张照片不会既按夜景校正又叠加胶片
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - 场景滤镜

/// 六种常用拍摄场景。
/// 参数都刻意压在温和区间（曝光不过一档、饱和不过 1.2），
/// 因为场景滤镜的目的是"把这个场景拍对"，而不是"给照片加个味道"。
enum SceneFilter: String, CaseIterable, Identifiable {

    case portrait    // 人像
    case landscape   // 风景
    case night       // 夜景
    case food        // 美食
    case indoor      // 室内
    case backlit     // 逆光

    var id: String { rawValue }

    var label: String {
        switch self {
        case .portrait:  return "人像"
        case .landscape: return "风景"
        case .night:     return "夜景"
        case .food:      return "美食"
        case .indoor:    return "室内"
        case .backlit:   return "逆光"
        }
    }

    /// 一行说清"这个场景最常出的问题"，用户才知道什么时候该点它
    var hint: String {
        switch self {
        case .portrait:  return "柔高光 · 肤色通透不过红"
        case .landscape: return "加通透层次 · 天空更蓝"
        case .night:     return "压灯牌高光 · 提亮暗部"
        case .food:      return "暖橙提亮 · 加强质感"
        case .indoor:    return "去白炽灯偏黄 · 回中性白"
        case .backlit:   return "补暗部 · 压高光保天空"
        }
    }

    /// 长说明，给「设计说明」用
    var detail: String {
        switch self {
        case .portrait:
            return "只柔化高光、暗部几乎不动，皮肤才不脏；暖调只加在 5% 以内，避免整张脸发橘"
        case .landscape:
            return "加中高调对比拉出层次，蓝通道轻推让天空更干净，锐化补偿缩图后的细节损失"
        case .night:
            return "提亮暗部保住建筑轮廓、压住灯牌过曝，冷调配合轻暗角压出夜感"
        case .food:
            return "暖橙增益 + 提饱和提亮，锐化强调表面质感，注意别让酱汁反光糊成一片"
        case .indoor:
            return "白炽灯下的黄膜用反向通道增益抵消，整体提亮到中性白，不靠提高对比硬撑"
        case .backlit:
            return "暗部大幅提亮当作补光、高光压回来保住天空，反差放平，逆光才不是一张黑影"
        }
    }
}

// MARK: - 风格滤镜

/// 每一项对应一条固定的 Core Image 链路；参数都落在系统建议区间内，
/// 保证同一张照片在不同机型上表现一致
enum PhotoFilter: String, CaseIterable, Identifiable {

    case none      // 原图
    case vivid     // 鲜明
    case soft      // 柔和
    case mono      // 黑白
    case silver    // 银盐
    case warm      // 暖阳
    case cool      // 冷调
    case film      // 胶片
    case punch     // 硬朗

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:   return "原图"
        case .vivid:  return "鲜明"
        case .soft:   return "柔和"
        case .mono:   return "黑白"
        case .silver: return "银盐"
        case .warm:   return "暖阳"
        case .cool:   return "冷调"
        case .film:   return "胶片"
        case .punch:  return "硬朗"
        }
    }

    /// 面板顶部的一行说明，告诉用户"这个滤镜在做什么"，而不是只给个名字
    var hint: String {
        switch self {
        case .none:   return "未调色，保留现场真实颜色"
        case .vivid:  return "饱和与对比略增"
        case .soft:   return "压低反差 · 提亮暗部"
        case .mono:   return "中性灰阶"
        case .silver: return "高反差灰阶 + 暗角"
        case .warm:   return "整体偏暖"
        case .cool:   return "整体偏冷"
        case .film:   return "低饱和 + 轻暗角"
        case .punch:  return "强对比 + 暗角"
        }
    }

    /// 是否会改变像素。原图直接透传，避免多做一次无谓的重编码
    var isIdentity: Bool { self == .none }
}

// MARK: - 统一选择

/// 面板上的一次选择：原图 / 某个场景 / 某种风格，三者互斥。
/// 场景与风格不叠加——否则"夜景 + 胶片"这种组合会把参数推到互相打架的地步，
/// 用户也说不清最后看到的偏色是哪一层造成的。
enum FilterChoice: Hashable {

    case original
    case scene(SceneFilter)
    case style(PhotoFilter)

    /// 把 PhotoFilter.none 归一化成「原图」，避免面板里出现两个"什么都没做"的入口。
    /// 用静态方法而不是 init，是为了和关联值 case 的 `FilterChoice.style(_:)` 区分开
    static func from(style: PhotoFilter) -> FilterChoice {
        style.isIdentity ? .original : .style(style)
    }

    /// 缓存键。缩略图按 key 存，预览按 key@强度 存
    var key: String {
        switch self {
        case .original:      return "original"
        case .scene(let s):  return "scene." + s.rawValue
        case .style(let f):  return "style." + f.rawValue
        }
    }

    var label: String {
        switch self {
        case .original:      return "原图"
        case .scene(let s):  return s.label
        case .style(let f):  return f.label
        }
    }

    var hint: String {
        switch self {
        case .original:      return "未调色，保留现场真实颜色"
        case .scene(let s):  return s.hint
        case .style(let f):  return f.hint
        }
    }

    /// 是否为"不做任何处理"
    var isIdentity: Bool {
        if case .original = self { return true }
        return false
    }
}

// MARK: - 渲染

enum FilterEngine {

    /// CIContext 构建代价高，全局复用一个；文档保证线程安全
    private static let context: CIContext = {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CIContext(options: [
            .workingColorSpace: space,
            .outputColorSpace: space,
            .cacheIntermediates: false      // 单次渲染，缓存中间结果只会白占内存
        ])
    }()

    /// 对一张已 upright 的 UIImage 应用滤镜；失败时原样返回，绝不吞掉用户照片
    ///
    /// - Parameter intensity: 0…1。1 为完整效果，0 为原图。
    ///   实现方式是把滤镜结果按比例溶回原图，而不是去插值各个参数——
    ///   这样暗角、照片效果这类"没法当参数拧"的链路也能正确按比例减弱。
    static func apply(_ choice: FilterChoice, to image: UIImage,
                      intensity: Double = 1.0) -> UIImage {
        let strength = min(max(intensity, 0), 1)
        guard !choice.isIdentity, strength > 0.005, let cg = image.cgImage else { return image }

        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let input = CIImage(cgImage: cg, options: [.colorSpace: space])
        var output = chain(choice, input)

        if strength < 0.995 {
            output = blend(original: input, filtered: output, amount: strength)
        }

        // 部分滤镜会扩张 extent（暗角、锐化），统一裁回原始范围
        let cropped = output.cropped(to: input.extent)
        guard let result = context.createCGImage(cropped, from: input.extent) else { return image }
        return UIImage(cgImage: result, scale: image.scale, orientation: .up)
    }

    /// 强度：逐像素线性插值 orig*(1-t) + filtered*t
    ///
    /// 做法是"原图乘 (1-t)"与"结果乘 t"相加，等价于溶解。
    /// 没有用 CIDissolveTransition —— 转场类滤镜在不同系统版本上的色域处理不完全一致，
    /// 而 colorMatrix / additionCompositing 是最基础的两个，行为稳定。
    private static func blend(original: CIImage, filtered: CIImage, amount: Double) -> CIImage {
        let t = CGFloat(amount)
        let target = filtered.cropped(to: original.extent)     // 先对齐范围，扩张部分不参与混合

        let keep = colorGain(original, red: 1 - t, green: 1 - t, blue: 1 - t)
        let add = colorGain(target, red: t, green: t, blue: t)

        let f = CIFilter.additionCompositing()
        f.inputImage = add
        f.backgroundImage = keep
        return f.outputImage ?? filtered
    }

    // MARK: 链路

    private static func chain(_ choice: FilterChoice, _ image: CIImage) -> CIImage {
        switch choice {
        case .original:
            return image
        case .scene(let scene):
            return sceneChain(scene, image)
        case .style(let style):
            return styleChain(style, image)
        }
    }

    // MARK: 场景链路
    //
    // 统一先做色调曲线（定暗部与高光的落点），再做通道增益（定冷暖），
    // 最后调饱和对比与锐化。顺序固定，方便逐项排查"偏色到底是哪一层来的"。

    private static func sceneChain(_ scene: SceneFilter, _ image: CIImage) -> CIImage {
        switch scene {

        case .portrait:
            // 抬暗部、压高光到 0.74，肤色亮度只提 3%——再往上推额头反光就会顶到死白。
            // 暖调靠"降蓝"而不是"升红"：R 不动，高光才不会被顺手推高。
            var img = curve(image, shadow: 0.300, midtone: 0.550, highlight: 0.740)
            img = colorGain(img, red: 1.03, green: 1.00, blue: 0.955)
            img = controls(img, saturation: 1.02, contrast: 0.97, brightness: 0.004)
            return img

        case .landscape:
            // 暗部压深、高光拉亮 = 加对比；蓝通道轻推让天空干净
            var img = curve(image, shadow: 0.212, midtone: 0.495, highlight: 0.782)
            img = colorGain(img, red: 0.98, green: 1.02, blue: 1.06)
            img = controls(img, saturation: 1.14, contrast: 1.08, brightness: 0)
            img = vibrance(img, 0.22)
            img = sharpen(img, 0.34)
            return img

        case .night:
            // 先整体降曝光把灯牌从 255 拉回来，再用曲线把建筑暗部补回去——
            // 这才是"压动态范围"。只靠曲线是压不住已经接近全白的高光的。
            var img = exposure(image, -0.13)
            img = curve(img, shadow: 0.430, midtone: 0.535, highlight: 0.705)
            img = colorGain(img, red: 0.96, green: 0.99, blue: 1.07)
            img = controls(img, saturation: 0.94, contrast: 1.00, brightness: -0.006)
            img = vignette(img, intensity: 0.26, radius: 1.05)
            return img

        case .food:
            var img = curve(image, shadow: 0.238, midtone: 0.512, highlight: 0.772)
            img = colorGain(img, red: 1.055, green: 1.00, blue: 0.942)
            img = controls(img, saturation: 1.14, contrast: 1.05, brightness: 0.010)
            img = vibrance(img, 0.18)
            img = sharpen(img, 0.36)
            return img

        case .indoor:
            // 白炽灯的偏黄用反向增益抵消，整体提亮，不靠拉对比硬撑亮度
            var img = curve(image, shadow: 0.305, midtone: 0.548, highlight: 0.782)
            img = colorGain(img, red: 0.90, green: 1.00, blue: 1.12)
            img = controls(img, saturation: 1.04, contrast: 1.02, brightness: 0.006)
            return img

        case .backlit:
            // 同样是"先降曝光再补暗部"：天空从 30% 过曝压到零，剪影亮度翻倍。
            // 单纯抬暗部的滤镜会把天空一起顶爆，逆光必须靠曝光先让出余量。
            var img = exposure(image, -0.20)
            img = curve(img, shadow: 0.490, midtone: 0.570, highlight: 0.760)
            img = colorGain(img, red: 1.03, green: 1.00, blue: 0.98)
            img = controls(img, saturation: 1.05, contrast: 0.90, brightness: 0.010)
            return img
        }
    }

    // MARK: 风格链路

    private static func styleChain(_ filter: PhotoFilter, _ image: CIImage) -> CIImage {
        switch filter {
        case .none:
            return image

        case .vivid:
            var img = controls(image, saturation: 1.24, contrast: 1.13, brightness: 0.012)
            img = vibrance(img, 0.22)
            img = sharpen(img, 0.32)
            return img

        case .soft:
            var img = exposure(image, 0.16)
            img = controls(img, saturation: 1.04, contrast: 0.90, brightness: 0.030)
            img = colorGain(img, red: 1.04, green: 1.01, blue: 0.97)
            return img

        case .mono:
            var img = photoEffect(image, .mono)
            img = controls(img, saturation: 0, contrast: 1.10, brightness: 0.010)
            return img

        case .silver:
            var img = photoEffect(image, .noir)
            img = controls(img, saturation: 0, contrast: 1.06, brightness: 0)
            img = vignette(img, intensity: 0.50, radius: 0.85)
            return img

        case .warm:
            var img = colorGain(image, red: 1.12, green: 1.02, blue: 0.88)
            img = controls(img, saturation: 1.08, contrast: 1.03, brightness: 0.015)
            return img

        case .cool:
            var img = colorGain(image, red: 0.90, green: 1.01, blue: 1.12)
            img = controls(img, saturation: 1.02, contrast: 1.05, brightness: 0)
            return img

        case .film:
            var img = photoEffect(image, .transfer)
            img = controls(img, saturation: 0.94, contrast: 0.98, brightness: 0.020)
            img = vignette(img, intensity: 0.34, radius: 1.10)
            return img

        case .punch:
            var img = controls(image, saturation: 0.94, contrast: 1.24, brightness: 0.005)
            img = sharpen(img, 0.40)
            img = vignette(img, intensity: 0.45, radius: 0.90)
            return img
        }
    }

    // MARK: 单项

    private static func controls(_ image: CIImage,
                                 saturation: Float,
                                 contrast: Float,
                                 brightness: Float) -> CIImage {
        let f = CIFilter.colorControls()
        f.inputImage = image
        f.saturation = saturation        // 0…2
        f.contrast = contrast            // 0.25…4
        f.brightness = brightness        // -1…1
        return f.outputImage ?? image
    }

    private static func vibrance(_ image: CIImage, _ amount: Float) -> CIImage {
        let f = CIFilter.vibrance()
        f.inputImage = image
        f.amount = amount                // -1…1，只推低饱和区域，肤色不易过火
        return f.outputImage ?? image
    }

    private static func sharpen(_ image: CIImage, _ sharpness: Float) -> CIImage {
        let f = CIFilter.sharpenLuminance()
        f.inputImage = image
        f.sharpness = sharpness          // 0…2
        f.radius = 1.2
        return f.outputImage ?? image
    }

    private static func exposure(_ image: CIImage, _ ev: Float) -> CIImage {
        let f = CIFilter.exposureAdjust()
        f.inputImage = image
        f.ev = ev                        // 以 EV 为单位，±1 约为曝光一档
        return f.outputImage ?? image
    }

    /// 暖冷调：直接用 RGB 通道增益，方向由数值决定，不依赖色温滤镜对白点的解释
    private static func colorGain(_ image: CIImage,
                                  red: CGFloat, green: CGFloat, blue: CGFloat) -> CIImage {
        let f = CIFilter.colorMatrix()
        f.inputImage = image
        f.rVector = CIVector(x: red,   y: 0,     z: 0,     w: 0)
        f.gVector = CIVector(x: 0,     y: green, z: 0,     w: 0)
        f.bVector = CIVector(x: 0,     y: 0,     z: blue,  w: 0)
        f.aVector = CIVector(x: 0,     y: 0,     z: 0,     w: 1)
        f.biasVector = CIVector(x: 0,  y: 0,     z: 0,     w: 0)
        return f.outputImage ?? image
    }

    private static func vignette(_ image: CIImage, intensity: Float, radius: Float) -> CIImage {
        let f = CIFilter.vignette()
        f.inputImage = image
        f.intensity = intensity          // 0…1
        f.radius = radius                // 0…2，以画面尺寸归一化
        return f.outputImage ?? image
    }

    /// 色调曲线：三个采样点直接给出"暗部抬到哪、中调落在哪、高光压到哪"。
    ///
    /// 特意没用 highlightShadowAdjust —— 那个的 highlightAmount 是"1 为不变、
    /// 越小压得越狠"还是反过来，各家理解不一，写反了逆光就会变成"高光更亮"。
    /// 用曲线后，方向由 y 值直接决定，不存在歧义。
    ///
    /// - Parameters:
    ///   - shadow: 输入 0.25 处的输出。< 0.25 压暗部，> 0.25 提暗部
    ///   - midtone: 输入 0.50 处的输出，决定整体明暗
    ///   - highlight: 输入 0.75 处的输出。< 0.75 压高光，> 0.75 拉亮高光
    private static func curve(_ image: CIImage,
                              shadow: CGFloat, midtone: CGFloat, highlight: CGFloat) -> CIImage {
        let f = CIFilter.toneCurve()
        f.inputImage = image
        f.point0 = CGPoint(x: 0.00, y: 0.00)
        f.point1 = CGPoint(x: 0.25, y: shadow)
        f.point2 = CGPoint(x: 0.50, y: midtone)
        f.point3 = CGPoint(x: 0.75, y: highlight)
        f.point4 = CGPoint(x: 1.00, y: 1.00)
        return f.outputImage ?? image
    }

    private enum Effect {
        case mono, noir, transfer

        var ciFilter: CIFilter {
            switch self {
            case .mono:     return CIFilter.photoEffectMono()
            case .noir:     return CIFilter.photoEffectNoir()
            case .transfer: return CIFilter.photoEffectTransfer()
            }
        }
    }

    private static func photoEffect(_ image: CIImage, _ effect: Effect) -> CIImage {
        let f = effect.ciFilter
        f.setValue(image, forKey: kCIInputImageKey)
        return f.outputImage ?? image
    }
}

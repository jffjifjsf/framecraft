//
//  DemoScene.swift
//  FrameCraft
//
//  模拟器或相机被拒时的降级画面：程序生成，人物会缓慢横移，
//  构图评分随位置真实变化 —— 与 Web 原型的演示场景一致。
//

import UIKit

enum DemoScene {

    static func render(size: CGSize, phase: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            draw(in: ctx.cgContext, size: size, phase: phase)
        }
    }

    private static func draw(in cg: CGContext, size: CGSize, phase: CGFloat) {
        let w = size.width
        let h = size.height
        let hz = h * 0.63

        // 天空
        let colors = [
            UIColor(red: 0.24, green: 0.43, blue: 0.66, alpha: 1).cgColor,
            UIColor(red: 0.76, green: 0.81, blue: 0.82, alpha: 1).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors, locations: [0, 1]) {
            cg.saveGState()
            cg.clip(to: CGRect(x: 0, y: 0, width: w, height: hz))
            cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: hz), options: [])
            cg.restoreGState()
        }

        // 太阳
        let sunR = h * 0.045
        cg.setFillColor(UIColor(red: 1, green: 0.93, blue: 0.80, alpha: 1).cgColor)
        cg.fillEllipse(in: CGRect(x: w * 0.72 - sunR, y: hz - h * 0.20 - sunR,
                                  width: sunR * 2, height: sunR * 2))

        // 远山
        let peaks: [(CGFloat, CGFloat)] = [(0, 0.52), (0.12, 0.34), (0.26, 0.46),
                                           (0.42, 0.28), (0.58, 0.44), (0.72, 0.36),
                                           (0.86, 0.47), (1, 0.38)]
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: hz))
        for p in peaks {
            path.addLine(to: CGPoint(x: p.0 * w, y: hz - p.1 * h * 0.42))
        }
        path.addLine(to: CGPoint(x: w, y: hz))
        path.closeSubpath()
        cg.setFillColor(UIColor(red: 0.13, green: 0.19, blue: 0.26, alpha: 1).cgColor)
        cg.addPath(path)
        cg.fillPath()

        // 地面
        cg.setFillColor(UIColor(red: 0.17, green: 0.22, blue: 0.15, alpha: 1).cgColor)
        cg.fill(CGRect(x: 0, y: hz, width: w, height: h - hz))

        // 边缘灌木（制造边缘干扰，供"画面干净"维度打分）
        cg.setFillColor(UIColor(red: 0.10, green: 0.14, blue: 0.10, alpha: 1).cgColor)
        cg.fillEllipse(in: CGRect(x: -w * 0.06, y: h * 0.80, width: w * 0.20, height: h * 0.16))
        cg.fillEllipse(in: CGRect(x: w * 0.88, y: h * 0.84, width: w * 0.22, height: h * 0.16))

        // 人物：缓慢横移
        let px = w * (0.5 + 0.24 * sin(phase))
        let baseY = h * 0.93
        let bodyH = h * 0.26
        let bodyW = w * 0.13
        let headR = h * 0.045

        // 影子
        cg.setFillColor(UIColor(white: 0, alpha: 0.30).cgColor)
        cg.fillEllipse(in: CGRect(x: px - bodyW * 0.75, y: baseY - h * 0.012,
                                  width: bodyW * 1.5, height: h * 0.028))

        // 身体
        let body = CGMutablePath()
        body.move(to: CGPoint(x: px - bodyW * 0.55, y: baseY))
        body.addQuadCurve(to: CGPoint(x: px - bodyW * 0.28, y: baseY - bodyH),
                          control: CGPoint(x: px - bodyW * 0.52, y: baseY - bodyH * 0.72))
        body.addLine(to: CGPoint(x: px + bodyW * 0.28, y: baseY - bodyH))
        body.addQuadCurve(to: CGPoint(x: px + bodyW * 0.55, y: baseY),
                          control: CGPoint(x: px + bodyW * 0.52, y: baseY - bodyH * 0.72))
        body.closeSubpath()
        cg.setFillColor(UIColor(red: 0.15, green: 0.18, blue: 0.23, alpha: 1).cgColor)
        cg.addPath(body)
        cg.fillPath()

        // 头（肤色，触发人像识别通道）
        let headY = baseY - bodyH - headR * 0.85
        cg.setFillColor(UIColor(red: 0.84, green: 0.64, blue: 0.49, alpha: 1).cgColor)
        cg.fillEllipse(in: CGRect(x: px - headR, y: headY - headR,
                                  width: headR * 2, height: headR * 2))

        // 头发
        let hair = CGMutablePath()
        hair.addArc(center: CGPoint(x: px, y: headY - headR * 0.10), radius: headR * 0.99,
                    startAngle: .pi * 1.06, endAngle: .pi * 1.94, clockwise: false)
        hair.closeSubpath()
        cg.setFillColor(UIColor(red: 0.14, green: 0.10, blue: 0.08, alpha: 1).cgColor)
        cg.addPath(hair)
        cg.fillPath()
    }
}

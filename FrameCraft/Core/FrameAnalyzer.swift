//
//  FrameAnalyzer.swift
//  FrameCraft
//
//  实时构图分析：显著度 → 主体框 → 对称/水平/干扰
//  纯自研，无第三方模型依赖；与 Web 原型逐行对应，参数已做数值验证。
//

import Foundation
import CoreVideo
import UIKit

struct FrameAnalyzer {

    /// 分析用的降采样宽度。越小越快，越大越准；168 是实机验证过的平衡点。
    static let AW = 168

    // MARK: - 入口：相机帧

    static func analyze(pixelBuffer: CVPixelBuffer, stageAspect: CGFloat,
                        detectFace: Bool = true) -> SubjectMetrics? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bw = CVPixelBufferGetWidth(pixelBuffer)
        let bh = CVPixelBufferGetHeight(pixelBuffer)
        let bpr = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard bw > 8, bh > 8, bpr >= bw * 4 else { return nil }

        // 预览是 resizeAspectFill，只分析真正看得见的那一块
        let aspect = max(0.4, min(2.6, stageAspect))
        var cw = CGFloat(bw)
        var ch = CGFloat(bh)
        if cw / ch > aspect { cw = ch * aspect } else { ch = cw / aspect }
        let crop = CGRect(x: (CGFloat(bw) - cw) / 2, y: (CGFloat(bh) - ch) / 2,
                          width: cw, height: ch)

        let ptr = base.assumingMemoryBound(to: UInt8.self)
        guard var m = core(ptr, bw, bh, bpr, crop, aspect) else { return nil }
        // 人脸关键点：与显著度主体并行，补上"眼线 / 头顶 / 视线"三个可算量
        if detectFace {
            m.face = FaceAnalyzer.detect(pixelBuffer: pixelBuffer,
                                         crop: crop,
                                         bufferSize: CGSize(width: CGFloat(bw), height: CGFloat(bh)))
        }
        return m
    }

    // MARK: - 入口：静态图（拍后诊断 / 相册）

    static func analyze(image: UIImage, detectFace: Bool = true) -> SubjectMetrics? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width
        let h = cg.height
        guard w > 8, h > 8 else { return nil }

        let bytesPerRow = w * 4
        let bytes = UnsafeMutableRawPointer.allocate(byteCount: bytesPerRow * h, alignment: 16)
        defer { bytes.deallocate() }

        guard let ctx = CGContext(data: bytes, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                            | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }

        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let ptr = bytes.assumingMemoryBound(to: UInt8.self)
        guard var m = core(ptr, w, h, bytesPerRow,
                           CGRect(x: 0, y: 0, width: w, height: h),
                           CGFloat(w) / CGFloat(h)) else { return nil }
        m.face = detectFace ? FaceAnalyzer.detect(image: image) : nil
        return m
    }

    // MARK: - 核心管线

    /// 像素格式约定：内存顺序 B,G,R,A（CVPixelBuffer 32BGRA 与 CGBitmapInfo.byteOrder32Little 一致）
    private static func core(_ base: UnsafePointer<UInt8>,
                             _ bw: Int, _ bh: Int, _ bpr: Int,
                             _ crop: CGRect, _ aspect: CGFloat) -> SubjectMetrics? {

        let aw = AW
        let ah = max(24, Int((CGFloat(aw) / aspect).rounded()))
        let n = aw * ah

        var gray = [Float](repeating: 0, count: n)
        var rr = [Float](repeating: 0, count: n)
        var gg = [Float](repeating: 0, count: n)
        var bb = [Float](repeating: 0, count: n)

        // 最近邻采样到 aw×ah
        for y in 0..<ah {
            let sy = Int(crop.minY + CGFloat(y) / CGFloat(ah) * crop.height)
            let row = min(bh - 1, max(0, sy)) * bpr
            for x in 0..<aw {
                let sx = Int(crop.minX + CGFloat(x) / CGFloat(aw) * crop.width)
                let i = row + min(bw - 1, max(0, sx)) * 4
                let b = Float(base[i])
                let g = Float(base[i + 1])
                let r = Float(base[i + 2])
                let k = y * aw + x
                rr[k] = r; gg[k] = g; bb[k] = b
                gray[k] = 0.299 * r + 0.587 * g + 0.114 * b
            }
        }

        // ---- Sobel ----
        var gxF = [Float](repeating: 0, count: n)
        var gyF = [Float](repeating: 0, count: n)
        var mag = [Float](repeating: 0, count: n)
        if ah > 2 && aw > 2 {
            for y in 1..<(ah - 1) {
                for x in 1..<(aw - 1) {
                    let i = y * aw + x
                    let tl = gray[i - aw - 1], tc = gray[i - aw], tr = gray[i - aw + 1]
                    let ml = gray[i - 1], mr = gray[i + 1]
                    let bl = gray[i + aw - 1], bc = gray[i + aw], br = gray[i + aw + 1]
                    let gx = (tr + 2 * mr + br) - (tl + 2 * ml + bl)
                    let gy = (bl + 2 * bc + br) - (tl + 2 * tc + tr)
                    gxF[i] = gx; gyF[i] = gy
                    mag[i] = (gx * gx + gy * gy).squareRoot()
                }
            }
        }

        // ---- 画面边缘平均色（全局背景模型） ----
        var edgeR: Float = 0, edgeG: Float = 0, edgeB: Float = 0, edgeN: Float = 0
        let bx = max(2, Int(Float(aw) * 0.06))
        let by = max(2, Int(Float(ah) * 0.06))
        for y in 0..<ah {
            for x in 0..<aw where (x < bx || x >= aw - bx || y < by || y >= ah - by) {
                let i = y * aw + x
                edgeR += rr[i]; edgeG += gg[i]; edgeB += bb[i]; edgeN += 1
            }
        }
        if edgeN > 0 { edgeR /= edgeN; edgeG /= edgeN; edgeB /= edgeN }

        // ---- 大尺度局部均值（局部背景模型，半径大于典型主体宽度）----
        let rad = max(4, Int(Float(aw) * 0.22))
        let bgR = boxBlur(rr, aw, ah, rad)
        let bgG = boxBlur(gg, aw, ah, rad)
        let bgB = boxBlur(bb, aw, ah, rad)

        // ---- 显著度 ----
        var sal = [Float](repeating: 0, count: n)
        let cx0 = Float(aw - 1) / 2
        let cy0 = Float(ah - 1) / 2
        var maxD = (cx0 * cx0 + cy0 * cy0).squareRoot()
        if maxD < 1 { maxD = 1 }
        var maxSal: Float = 0
        var skinCnt = 0

        for y in 0..<ah {
            for x in 0..<aw {
                let i = y * aw + x
                let R = rr[i], G = gg[i], B = bb[i]
                let e = min(1, mag[i] / 105)
                let cdG = (abs(R - edgeR) + abs(G - edgeG) + abs(B - edgeB)) / 300
                let cdL = (abs(R - bgR[i]) + abs(G - bgG[i]) + abs(B - bgB[i])) / 300
                let cd = max(cdL, cdG * 0.5)

                let fx = Float(x) - cx0, fy = Float(y) - cy0
                let dist = (fx * fx + fy * fy).squareRoot() / maxD
                let cp = 1 - 0.22 * dist          // 中心先验必须弱，否则边缘主体检测不到

                let mx = max(R, max(G, B))
                let mn = min(R, min(G, B))
                let skin = (R > 95 && G > 40 && B > 20 && mx - mn > 15
                            && abs(R - G) > 15 && R > G && R > B)
                if skin { skinCnt += 1 }

                var s = (0.5 * e + 0.5 * min(1, cd * 1.7)) * (0.58 + 0.42 * cp)
                if skin { s *= 1.35 }
                sal[i] = s
                if s > maxSal { maxSal = s }
            }
        }
        if maxSal <= 0 { return nil }

        // ---- 密度化：抑制地平线这类细长边缘 ----
        sal = boxBlur(sal, aw, ah, 4)

        // ---- 中心-周边抑制：压掉"环境本身就很显著"的底噪 ----
        let bgSal = boxBlur(sal, aw, ah, max(6, Int(Float(aw) * 0.26)))
        for i in 0..<n {
            let v = sal[i] - 0.62 * bgSal[i]
            sal[i] = v > 0 ? v : 0
        }

        // ---- 积分图 ----
        let W1 = aw + 1
        var integral = [Double](repeating: 0, count: W1 * (ah + 1))
        for y in 0..<ah {
            var rowSum = 0.0
            for x in 0..<aw {
                rowSum += Double(sal[y * aw + x])
                integral[(y + 1) * W1 + (x + 1)] = integral[y * W1 + (x + 1)] + rowSum
            }
        }

        func boxSum(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) -> Double {
            integral[(y1 + 1) * W1 + (x1 + 1)]
                - integral[y0 * W1 + (x1 + 1)]
                - integral[(y1 + 1) * W1 + x0]
                + integral[y0 * W1 + x0]
        }

        var totalSal = integral[ah * W1 + aw]
        if totalSal <= 0 { return nil }

        // ---- 多尺度窗口搜索：均值显著度 × 质量占比 ----
        var bestScore = -1.0
        var bxs0 = 0, bys0 = 0, bxs1 = 0, bys1 = 0
        let scales: [CGFloat] = [0.20, 0.30, 0.42, 0.56, 0.70]
        let stepX = max(1, Int(Float(aw) * 0.04))
        let stepY = max(1, Int(Float(ah) * 0.04))

        func consider(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) {
            let sum = boxSum(x0, y0, x1, y1)
            let w = Double(x1 - x0 + 1)
            let h = Double(y1 - y0 + 1)
            let mean = sum / (w * h)
            let frac = max(sum / totalSal, 1e-6)
            let score = mean * pow(frac, 0.35)
            if score > bestScore {
                bestScore = score
                bxs0 = x0; bys0 = y0; bxs1 = x1; bys1 = y1
            }
        }

        for sc in scales {
            let bw2 = max(4, Int((CGFloat(aw) * sc).rounded()))
            let bh2 = max(4, Int((CGFloat(ah) * sc).rounded()))
            guard bw2 < aw - 1, bh2 < ah - 1 else { continue }
            var y0 = 0
            while y0 <= ah - bh2 {
                var x0 = 0
                while x0 <= aw - bw2 {
                    consider(x0, y0, x0 + bw2 - 1, y0 + bh2 - 1)
                    x0 += stepX
                }
                y0 += stepY
            }
        }
        guard bestScore >= 0 else { return nil }

        // 相邻位置细化（步长降到 1）
        let rw = bxs1 - bxs0 + 1
        let rh = bys1 - bys0 + 1
        let ryA = max(0, bys0 - stepY * 2)
        let ryB = min(ah - rh, bys0 + stepY * 2)
        let rxA = max(0, bxs0 - stepX * 2)
        let rxB = min(aw - rw, bxs0 + stepX * 2)
        if ryB >= ryA && rxB >= rxA {
            for y0 in ryA...ryB {
                for x0 in rxA...rxB {
                    consider(x0, y0, x0 + rw - 1, y0 + rh - 1)
                }
            }
        }

        var x0 = bxs0, x1 = bxs1, y0 = bys0, y1 = bys1

        // ---- 窗口内收缩：剥离框里的大片背景 ----
        func span1d(_ vals: [Float]) -> (Int, Int) {
            guard vals.count > 1 else { return (0, max(0, vals.count - 1)) }
            var pk = 0
            for i in 1..<vals.count where vals[i] > vals[pk] { pk = i }
            let th = vals[pk] * 0.45
            var lo = pk, hi = pk, miss = 0
            while hi < vals.count - 1 && miss < 3 {
                hi += 1
                if vals[hi] >= th { miss = 0 } else { miss += 1 }
            }
            miss = 0
            while lo > 0 && miss < 3 {
                lo -= 1
                if vals[lo] >= th { miss = 0 } else { miss += 1 }
            }
            return (lo, hi)
        }

        var cols = [Float](repeating: 0, count: x1 - x0 + 1)
        for x in x0...x1 {
            var s: Float = 0
            for y in y0...y1 { s += sal[y * aw + x] }
            cols[x - x0] = s
        }
        var rows = [Float](repeating: 0, count: y1 - y0 + 1)
        for y in y0...y1 {
            var s: Float = 0
            for x in x0...x1 { s += sal[y * aw + x] }
            rows[y - y0] = s
        }
        let (cLo, cHi) = span1d(cols)
        let (rLo, rHi) = span1d(rows)
        let minW = max(4, Int(Float(x1 - x0 + 1) * 0.35))
        let minH = max(4, Int(Float(y1 - y0 + 1) * 0.35))
        var nx0 = x0 + cLo, nx1 = x0 + cHi, ny0 = y0 + rLo, ny1 = y0 + rHi
        if nx1 - nx0 + 1 < minW {
            let mid = (nx0 + nx1) / 2
            nx0 = mid - minW / 2
            nx1 = nx0 + minW - 1
        }
        if ny1 - ny0 + 1 < minH {
            let mid = (ny0 + ny1) / 2
            ny0 = mid - minH / 2
            ny1 = ny0 + minH - 1
        }
        x0 = min(max(nx0, 0), aw - 1); x1 = min(max(nx1, 0), aw - 1)
        y0 = min(max(ny0, 0), ah - 1); y1 = min(max(ny1, 0), ah - 1)
        if x1 <= x0 { x1 = min(aw - 1, x0 + 1) }
        if y1 <= y0 { y1 = min(ah - 1, y0 + 1) }

        // ---- 质心（平方加权）+ 紧致框 ----
        var maxIn: Float = 1e-6
        for y in y0...y1 {
            for x in x0...x1 {
                let v = sal[y * aw + x]
                if v > maxIn { maxIn = v }
            }
        }
        let thrIn = maxIn * 0.42
        var mSum = 0.0, mx2 = 0.0, my2 = 0.0
        var tx0 = Int.max, tx1 = Int.min, ty0 = Int.max, ty1 = Int.min
        for y in y0...y1 {
            for x in x0...x1 {
                let v = sal[y * aw + x]
                let w = Double(v) * Double(v)
                mSum += w; mx2 += w * Double(x); my2 += w * Double(y)
                if v >= thrIn {
                    tx0 = min(tx0, x); tx1 = max(tx1, x)
                    ty0 = min(ty0, y); ty1 = max(ty1, y)
                }
            }
        }
        if mSum <= 0 { mSum = 1 }
        let cen = CGPoint(x: CGFloat(mx2 / mSum) / CGFloat(aw),
                          y: CGFloat(my2 / mSum) / CGFloat(ah))
        if tx1 - tx0 >= 3 && ty1 - ty0 >= 3 {
            x0 = tx0; x1 = tx1; y0 = ty0; y1 = ty1
        }

        // ---- 左右 / 上下配平 ----
        var mL = 0.0, mR = 0.0, mT = 0.0, mB = 0.0, tot = 0.0
        let cenX = cen.x * CGFloat(aw)
        let cenY = cen.y * CGFloat(ah)
        for y in 0..<ah {
            for x in 0..<aw {
                let v = Double(sal[y * aw + x])
                tot += v
                if CGFloat(x) < cenX { mL += v } else { mR += v }
                if CGFloat(y) < cenY { mT += v } else { mB += v }
            }
        }
        if tot <= 0 { return nil }
        let lrDen = (mL + mR) == 0 ? 1 : (mL + mR)
        let tbDen = (mT + mB) == 0 ? 1 : (mT + mB)
        let lr = CGFloat((mL - mR) / lrDen)
        let tb = CGFloat((mT - mB) / tbDen)

        // ---- 边缘干扰 ----
        var edgeSal: Double = 0
        let ex = Int(Float(aw) * 0.07)
        let ey = Int(Float(ah) * 0.07)
        for y in 0..<ah {
            for x in 0..<aw where (x < ex || x >= aw - ex || y < ey || y >= ah - ey) {
                edgeSal += Double(sal[y * aw + x])
            }
        }
        let clutter = CGFloat(edgeSal / tot)

        // ---- 对称性 ----
        var bestDiff = Float.greatestFiniteMagnitude
        var bestAxis: CGFloat = 0.5
        if ah > 6 && aw > 8 {
            for t in 0...24 {
                let ax = 0.42 + CGFloat(t) * 0.00667
                let px = Float(ax) * Float(aw - 1)
                let spanPx = Int(min(px, Float(aw - 1) - px))
                if spanPx < 3 { continue }
                var diff: Float = 0
                var cnt = 0
                var y = 2
                while y < ah - 2 {
                    let row = y * aw
                    for d in 1..<spanPx {
                        let l = gray[row + Int(px - Float(d))]
                        let r = gray[row + Int(px + Float(d))]
                        diff += abs(l - r)
                        cnt += 1
                    }
                    y += 2
                }
                if cnt > 0 {
                    let dd = diff / Float(cnt)
                    if dd < bestDiff { bestDiff = dd; bestAxis = ax }
                }
            }
        }
        var symmetry: CGFloat = 0
        if bestDiff < Float.greatestFiniteMagnitude {
            symmetry = min(max(1 - CGFloat(bestDiff) / 38, 0), 1)
        }

        // ---- 倾斜 / 地平线 ----
        var sw2 = 0.0, sdev = 0.0, wsum = 0.0
        var rowEdge = [Float](repeating: 0, count: ah)
        if ah > 2 && aw > 2 {
            for y in 1..<(ah - 1) {
                for x in 1..<(aw - 1) {
                    let i = y * aw + x
                    let mm = mag[i]
                    if mm < 26 { continue }
                    let deg = Double(atan2(Double(gyF[i]), Double(gxF[i]))) * 180 / Double.pi
                    if abs(abs(deg) - 90) < 24 {
                        let dev = deg - (deg >= 0 ? 90 : -90)
                        sdev += dev * Double(mm)
                        sw2 += Double(mm)
                        rowEdge[y] += mm
                    }
                }
            }
        }
        if sw2 > 0 { wsum = sw2 }
        let tilt = wsum > 0 ? CGFloat(-(sdev / wsum)) : 0
        var hzRow = 0
        if ah > 2 {
            for y in 1..<(ah - 1) where rowEdge[y] > rowEdge[hzRow] { hzRow = y }
        }
        let horizonY = CGFloat(hzRow) / CGFloat(ah)

        let box = CGRect(x: CGFloat(x0) / CGFloat(aw),
                         y: CGFloat(y0) / CGFloat(ah),
                         width: CGFloat(x1 - x0 + 1) / CGFloat(aw),
                         height: CGFloat(y1 - y0 + 1) / CGFloat(ah))

        let conf: CGFloat = (box.width > 0.04 && box.height > 0.04 && maxIn > 0.14) ? 1 : 0.5

        return SubjectMetrics(box: box,
                              centroid: cen,
                              area: box.width * box.height,
                              skinRatio: CGFloat(skinCnt) / CGFloat(n),
                              symmetry: symmetry,
                              symAxis: bestAxis,
                              tilt: tilt,
                              horizonY: horizonY,
                              clutter: clutter,
                              balanceLR: lr,
                              balanceTB: tb,
                              confidence: conf,
                              peak: CGFloat(maxIn))
    }

    // MARK: - 盒式模糊（积分图，O(1) 半径）

    private static func boxBlur(_ src: [Float], _ w: Int, _ h: Int, _ r: Int) -> [Float] {
        let W1 = w + 1
        var integral = [Double](repeating: 0, count: W1 * (h + 1))
        for y in 0..<h {
            var s = 0.0
            let base = y * w
            for x in 0..<w {
                s += Double(src[base + x])
                integral[(y + 1) * W1 + (x + 1)] = integral[y * W1 + (x + 1)] + s
            }
        }
        var out = [Float](repeating: 0, count: w * h)
        let rr = max(1, r)
        for y in 0..<h {
            let y0 = max(0, y - rr)
            let y1 = min(h - 1, y + rr)
            for x in 0..<w {
                let x0 = max(0, x - rr)
                let x1 = min(w - 1, x + rr)
                let s = integral[(y1 + 1) * W1 + (x1 + 1)]
                    - integral[y0 * W1 + (x1 + 1)]
                    - integral[(y1 + 1) * W1 + x0]
                    + integral[y0 * W1 + x0]
                out[y * w + x] = Float(s / Double((x1 - x0 + 1) * (y1 - y0 + 1)))
            }
        }
        return out
    }
}

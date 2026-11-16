# FrameCraft

[![iOS 编译校验](https://github.com/jffjifjsf/framecraft/actions/workflows/ios-build.yml/badge.svg?branch=main)](https://github.com/jffjifjsf/framecraft/actions/workflows/ios-build.yml)

> 实时构图辅助相机。取景时告诉你主体在哪、差在哪里；按下快门后给一份可以左右拖动对比的诊断。

原生 iOS 应用，SwiftUI + AVFoundation + Vision，**零第三方依赖**，4428 行 Swift。

**编译状态**：GitHub Actions 在 macOS 15 + Xcode 16.4 上实测 `BUILD SUCCEEDED`（模拟器目标，不签名）。

---

## 它解决什么问题

大多数相机只负责"拍清楚"，不负责"拍好看"。构图这件事——主体放在哪、占多大、地平线平不平、留白够不够——全靠经验，而经验要几百张照片才长出来。

FrameCraft 在取景框里实时算这些，把"凭感觉"变成"看得见的分数"。

## 核心能力

### 实时引导（取景时）

- **主体识别**：显著度分析（Sobel 边缘 + 局部背景差 + 肤色），不是简单的中心裁剪
- **构图引导线**：五分法 / 黄金分割 / 中心 / 对称，一键循环
- **实时评分**：六维打分，逐项告诉你怎么改
- **人像模式**：Vision 检测到人脸时自动切七维，额外评估眼睛位置、头顶留白、视线方向
- **取景框时间平滑**：EMA 降抖 50%，面积突变自动旁路，框不跳不拖

### 拍摄控制

- 捏合变焦 + 1x/2x/3x 快捷档（`videoZoomFactor`，上限 5x）
- 点按对焦/测光，2 秒后自动松回连续对焦
- 双击复位
- 快门触感反馈、连拍防护

### 拍后诊断

- **可拖拽对比滑块**：左原图 / 右建议构图，手指划到哪对比到哪
- **智能裁剪**：按目标比例内接，主体吸附三分位（有脸时锚点用眼线）
- 逐项评分 + 改进建议

### 调色

- **6 种场景滤镜**：人像 / 风景 / 夜景 / 美食 / 室内 / 逆光
- **9 种风格滤镜**：鲜艳 / 柔和 / 黑白 / 银盐 / 暖调 / 冷调 / 胶片 / 强对比
- 强度 0–100% 无级调节，实时预览
- 全部基于 CoreImage 原语（色调曲线、通道增益、自然饱和度、锐化、暗角）

### 其他

- 相册保存（`AlbumStore`）
- 内建演示场景，模拟器无相机也能看效果

## 技术实现

| 模块 | 文件 | 职责 |
|---|---|---|
| 实时分析 | `Core/FrameAnalyzer.swift` | 显著度主体识别、智能裁剪、几何计算 |
| 人脸 | `Core/FaceAnalyzer.swift` | Vision 人脸关键点，六维扩七维 |
| 评分 | `Core/Models.swift` | `CompositionEngine` 多维加权评分与建议生成 |
| 相机 | `Core/CameraController.swift` | 会话管理、帧分析节流、变焦、对焦、平滑 |
| 滤镜 | `Core/ImageFilter.swift` | 场景/风格滤镜定义与渲染引擎 |
| 取景界面 | `UI/CameraView.swift` | 预览层、手势、叠加层、HUD |
| 复盘界面 | `UI/ReviewView.swift` | 对比滑块、评分详情、相册 |
| 滤镜面板 | `UI/FilterStrip.swift` | 缩略图异步渲染、强度调节、缓存 |

### 主体识别链路

```
168px 降采样
  → Sobel 边缘 + 大尺度局部均值背景差 + 肤色概率
  → 显著度图
  → 密度化模糊 + 中心-周边抑制
  → 积分图多尺度窗口搜索（均值 × 质量占比^0.35，0.20~0.70）
  → 窗口内收缩 + 平方加权质心
  → EMA 时间平滑（位置 0.35 / 尺寸 0.22，面积突变 2.2× 旁路，0.4% 死区）
```

### 评分权重

无人脸（六维）：位置 `.28` · 占比 `.18` · 水平 `.14` · 干净 `.14` · 留白 `.12` · 平衡 `.14`

有人脸（七维）：位置 `.22` · 占比 `.14` · 水平 `.10` · 干净 `.10` · 留白 `.08` · 平衡 `.10` · **人像 `.26`**

人像细节分 = `0.40 × 眼线位置 + 0.34 × 头顶留白 + 0.26 × 视线方向`

## 构建

### 本地（需要 macOS + Xcode 15 以上）

```bash
xcodebuild -list -project FrameCraft.xcodeproj          # 先验证工程可解析
./build.sh --sim                                        # 模拟器编译，不签名
TEAM_ID=你的团队ID ./build.sh                            # 出真机包
```

### 云端（没有 Mac 也能验编译）

仓库自带 `.github/workflows/ios-build.yml`，push 即触发：

- `runs-on: macos-15`，Xcode 16.x
- `CODE_SIGNING_ALLOWED=NO` 绕开签名，**不需要 Apple 开发者账号**
- 编译错误自动汇总到 Actions 摘要页，不用翻几千行日志

## 已知限制

- **主体识别是显著度启发式，不是语义分割**。纯色背景上的多个物体可能被合并成一框
- **人脸链路必须真机验证**。iOS 模拟器没有摄像头，`Vision` 检不出人脸
- `captureDevicePointConverted` 在前置 + `resizeAspectFill` 下的方向映射需真机确认
- 实时分析跑在 `framecraft.video` 队列、10fps 节流；Debug 构建偏慢，性能请用 Release 测
- 出 IPA 需要签名证书，CI 只验证编译，不产出可安装包

## 目录结构

```
FrameCraft/
├── FrameCraft.xcodeproj/          手写工程文件（objectVersion 56）
├── FrameCraft/
│   ├── App/                       App 入口
│   ├── Core/                      分析与渲染引擎
│   ├── UI/                        SwiftUI 界面
│   └── Resources/                 Info.plist、Assets.xcassets
├── build.sh                       本地编译脚本
└── .github/workflows/             云端编译校验
```

## 设计取舍

- **不做云端大模型构图**。构图引导必须在本机 100ms 内出结果，网络往返毁掉实时性。因此选 Vision + 显著度启发式，全部端上计算
- **不做账号体系**。一个拍照工具不需要登录
- **不保存原图副本**。成片写系统相册，App 内不堆积数据

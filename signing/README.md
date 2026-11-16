# 签名打包（Windows 上也能出 IPA）

目标：用你手上的 `.p12` + `.mobileprovision`，在 GitHub 的 macOS 机器上签出一个能装进 iPhone 的 IPA。
本地不需要 Mac、不需要 Xcode。

---

## 三步

### ① 生成 Secrets 的值

把 `.p12` 和 `.mobileprovision` 放进工作区根目录的 `keys` 文件夹，然后双击同目录的 `make-signing-secrets.bat`。

> 也可以把两个文件一起拖到 `.bat` 上，效果一样。文件夹方式更省事，脚本会自己找。

它会：

- 解析描述文件，打印 App ID / 团队 / 过期时间 / **登记设备数**
- 提前报出「能打包但装不上」的问题（App ID 对不上、已过期、没登记设备）
- 生成 `FRAMECRAFT_CERT.b64`、`FRAMECRAFT_PROFILE.b64`，并把描述文件那份放进剪贴板

> 解析用的是 Git for Windows 自带的 openssl。找不到也能继续，只是少了预检。

### ② 填进 GitHub Secrets

仓库 → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| 名称 | 值 |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | `FRAMECRAFT_CERT.b64` 的全部内容 |
| `P12_PASSWORD` | 导出 `.p12` 时设的密码 |
| `BUILD_PROVISION_PROFILE_BASE64` | `FRAMECRAFT_PROFILE.b64` 的全部内容 |
| `KEYCHAIN_PASSWORD` | 随便一串随机字符（CI 建临时钥匙串用，用完销毁） |

`.b64` 内容是一整行，用记事本 Ctrl+A / Ctrl+C 全选复制即可。**不要**把 `.p12` 本身提交进仓库（`.gitignore` 已挡）。

### ③ 手动跑一次

仓库 → **Actions** → 左侧 **iOS 签名打包** → **Run workflow** → 绿色按钮。

`export_method` 留 `auto` 就行，CI 会从描述文件里自己判断：

| 描述文件特征 | 自动判定 |
|---|---|
| `ProvisionsAllDevices = true` | `enterprise` |
| `get-task-allow = true` | `development` |
| 其余（有设备清单） | `ad-hoc` |

跑完在运行页面底部下载 **FrameCraft-ipa** 压缩包，里面就是 `.ipa`。

---

## 装到 iPhone（Windows）

IPA 已签名，直接侧载即可：

- **Sideloadly**（推荐，Windows 原生）—— 需要装 iTunes 的驱动组件；连上 iPhone，拖入 IPA，点 Start。**不要勾 "Use automatic signing"**，否则它会把你的签名替换掉
- **AltStore / SideStore** —— 适合长期自签续期
- **iMazing** —— 也能装，但会要求信任描述文件

装完在 iPhone 上：设置 → 通用 → VPN与设备管理 → 信任你的开发者证书。

---

## 装不上时对照

| iPhone 上的提示 | 原因 | 怎么修 |
|---|---|---|
| **无法安装此 App**（图标变灰） | 这台设备的 UDID 不在描述文件里 | developer.apple.com → Devices 添加 UDID → 重新生成描述文件 → 换掉 `BUILD_PROVISION_PROFILE_BASE64` |
| 安装后闪一下就退出 | 描述文件过期，或证书与描述文件不配对 | 看 CI 摘要里的「过期时间」；证书和描述文件必须来自同一团队 |
| `Provisioning profile doesn't match...` | 描述文件的 App ID 与 bundle id 不匹配 | CI 已用命令行把 bundle id 覆盖成描述文件的 App ID，若仍报错，说明描述文件是**通配**但工程带了额外 entitlement |
| `No signing certificate "iOS Development" found` | `.p12` 里只有证书没有私钥 | 重新导出：钥匙串访问 → 选中证书**和**私钥 → 导出 |
| `The specified item could not be found in the keychain` | `P12_PASSWORD` 错了 | 重填密码；密码里有特殊字符时不要加引号 |

---

## 流水线做了什么（`ios-ipa.yml`）

1. 检查 4 个 Secret 是否齐全，缺哪个直接点名报错
2. 把 `.p12` 导入临时钥匙串（`security import`，不碰 runner 的系统钥匙串）
3. 装描述文件到 `~/Library/MobileDevice/Provisioning Profiles`，用 `security cms -D` 解析出 UUID / 团队 / App ID / 设备数 / 导出方式
4. `xcodebuild archive` —— 命令行覆盖成 `CODE_SIGN_STYLE=Manual`，避免和工程里的 `Automatic` 打架
5. `xcodebuild -exportArchive` 用动态生成的 `ExportOptions.plist`（manual + provisioningProfiles 映射）
6. 汇总结果写进 Actions 摘要页，IPA 作为 artifact 上传，最后销毁钥匙串

只在 `workflow_dispatch` 手动触发，不影响每次 push 的「iOS 编译校验」。

<#
.SYNOPSIS
    把 .p12 与 .mobileprovision 转成 GitHub Secrets，并在上传前先把描述文件拆开检查一遍。

.DESCRIPTION
    GitHub Actions 里签名需要 4 个 Secret，其中两个是文件的 base64。
    这个脚本做三件事：
      1. 解析描述文件，打印 App ID / 团队 / 过期时间 / 登记设备数
      2. 提前报出会直接导致"打包成功但装不上"的问题（App ID 对不上、已过期、没有设备）
      3. 生成两个 base64 文件并复制到剪贴板，直接粘进 GitHub 网页

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File prepare-secrets.ps1 `
        -P12 "C:\keys\dev.p12" -Profile "C:\keys\dev.mobileprovision"
#>

param(
    [Parameter(Mandatory = $true)][string]$P12,
    [Parameter(Mandatory = $true)][string]$Profile
)

$ErrorActionPreference = 'Stop'
$ProjectBundleId = 'com.framecraft.camera'

function Line($s = '') { Write-Host $s }

Line '================================================'
Line ' FrameCraft  签名材料检查'
Line '================================================'
Line ''

foreach ($p in @($P12, $Profile)) {
    if (-not (Test-Path $p)) { Line "[FAIL] 文件不存在: $p"; exit 1 }
}
Line "[1/4] 文件都在"
Line ("       p12       : {0}  ({1:N1} KB)" -f (Split-Path $P12 -Leaf), ((Get-Item $P12).Length / 1KB))
Line ("       描述文件  : {0}  ({1:N1} KB)" -f (Split-Path $Profile -Leaf), ((Get-Item $Profile).Length / 1KB))

# ---------------------------------------------------------------- 2. 解析描述文件
Line ''
Line '[2/4] 解析描述文件 ...'

$openssl = $null
foreach ($cand in @('openssl', 'C:\Program Files\Git\usr\bin\openssl.exe',
                    'C:\Program Files\Git\mingw64\bin\openssl.exe')) {
    $cmd = Get-Command $cand -ErrorAction SilentlyContinue
    if ($cmd) { $openssl = $cmd.Source; break }
}
if (-not $openssl) {
    Line '       [WARN] 找不到 openssl（Git for Windows 自带），跳过解析'
    $plist = $null
} else {
    $tmp = Join-Path $env:TEMP ("fc_profile_{0}.plist" -f (Get-Random))

    # openssl 成功时也会往 stderr 写一行 "CMS Verification successful"，
    # 而脚本开头是 Stop 模式，native 命令的 stderr 会被当成致命错误 —— 这里必须临时放宽
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $openssl cms -verify -noverify -inform der -in $Profile -out $tmp 2>$null | Out-Null
        if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -lt 100) {
            & $openssl smime -verify -noverify -inform der -in $Profile -out $tmp 2>$null | Out-Null
        }
    } finally {
        $ErrorActionPreference = $prevEAP
    }

    if ((Test-Path $tmp) -and (Get-Item $tmp).Length -ge 100) {
        $raw = [IO.File]::ReadAllText($tmp, [Text.Encoding]::UTF8)
        try { $plist = [xml]$raw } catch { $plist = $null }
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    } else { $plist = $null }
}

$info = @{}
if ($plist) {
    function PlistVal($node, $key) {
        $n = $node.SelectSingleNode("//key[.='$key']/following-sibling::*[1]")
        if (-not $n) { return $null }
        # <true/> / <false/> 是空元素，InnerText 为空串，必须看节点名
        if ($n.Name -eq 'true')  { return 'true' }
        if ($n.Name -eq 'false') { return 'false' }
        if ($n.Name -eq 'array') { return @($n.ChildNodes | ForEach-Object { $_.InnerText }) }
        if ($n.Name -eq 'dict')   { return $n }
        return $n.InnerText
    }
    $d = $plist.plist.dict
    $info.Name   = PlistVal $d 'Name'
    $info.UUID   = PlistVal $d 'UUID'
    $info.Team   = @(PlistVal $d 'TeamIdentifier')[0]
    $info.Exp    = PlistVal $d 'ExpirationDate'
    $info.AllDev = PlistVal $d 'ProvisionsAllDevices'
    $ents = PlistVal $d 'Entitlements'
    $info.AppId  = if ($ents) { PlistVal $ents 'application-identifier' } else { $null }
    $info.GetTask= if ($ents) { PlistVal $ents 'get-task-allow' } else { $null }
    $devs = PlistVal $d 'ProvisionedDevices'
    $info.Devices = @($devs | Where-Object { $_ })
    # 空数组在 PowerShell 里是假值，必须先算成数字再判断
    $info.DevCount = if ($info.Devices) { $info.Devices.Count } else { 0 }

    Line ("       名称      : {0}" -f $info.Name)
    Line ("       UUID      : {0}" -f $info.UUID)
    Line ("       团队      : {0}" -f $info.Team)
    Line ("       App ID    : {0}" -f $info.AppId)
    Line ("       过期时间  : {0}" -f $info.Exp)
    Line ("       登记设备  : {0} 台" -f $info.DevCount)
    $kind = if ($info.AllDev -eq 'true') { '企业（in-house）' }
            elseif ($info.GetTask -eq 'true') { '开发（development）' }
            else { 'Ad-Hoc' }
    Line ("       类型      : {0}" -f $kind)
} else {
    Line '       [WARN] 无法解析 XML，只能生成 base64（CI 会再解析一遍）'
}

# ---------------------------------------------------------------- 3. 预检
Line ''
Line '[3/4] 预检 ...'
$problems = 0

if ($info.AppId) {
    $bundle = ($info.AppId -split '\.', 2)[1]
    if ($bundle -eq '*') {
        Line '       [OK] 通配 App ID，工程原 bundle id 可直接用'
    } elseif ($bundle -ne $ProjectBundleId) {
        Line ("       [注意] 描述文件绑定 {0}，与工程的 {1} 不同" -f $bundle, $ProjectBundleId)
        Line '              CI 会用命令行把 bundle id 覆盖成前者，通常不用改工程'
    } else {
        Line ("       [OK] App ID 与工程一致（{0}）" -f $ProjectBundleId)
    }
}

if ($info.Exp) {
    try {
        $exp = [DateTime]::Parse($info.Exp, [Globalization.CultureInfo]::InvariantCulture)
        $days = [int]($exp - (Get-Date)).TotalDays
        if ($days -lt 0) { Line ("       [问题] 描述文件已于 {0:yyyy-MM-dd} 过期，签出来的包装不上" -f $exp); $problems++ }
        elseif ($days -lt 14) { Line ("       [注意] 还有 {0} 天过期（{1:yyyy-MM-dd}）" -f $days, $exp) }
        else { Line ("       [OK] 有效期还剩 {0} 天" -f $days) }
    } catch { }
}

if ($info.DevCount -eq 0 -and $info.AllDev -ne 'true' -and $info.GetTask -ne 'true') {
    Line '       [问题] 描述文件里登记的设备数为 0'
    Line '              这类描述文件（App Store 类型）签出来的 IPA 不能直装 iPhone。'
    Line '              直装需要 development / ad-hoc 描述文件，且你的 UDID 已在里面：'
    Line '              developer.apple.com → Devices 添加 UDID → 重新生成描述文件'
    $problems++
}

# ---------------------------------------------------------------- 4. 产出 base64
Line ''
Line '[4/4] 生成 base64 ...'
$outDir = Split-Path $P12 -Parent
$certB64 = Join-Path $outDir 'FRAMECRAFT_CERT.b64'
$profB64 = Join-Path $outDir 'FRAMECRAFT_PROFILE.b64'

[IO.File]::WriteAllText($certB64, [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $P12))))
[IO.File]::WriteAllText($profB64, [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $Profile))))

Line ("       证书 base64   : {0}  ({1:N0} 字符)" -f $certB64, (Get-Content $certB64 -Raw).Length)
Line ("       描述文件 base64: {0}  ({1:N0} 字符)" -f $profB64, (Get-Content $profB64 -Raw).Length)

try {
    Set-Clipboard -Value ([IO.File]::ReadAllText($profB64))
    Line '       描述文件 base64 已复制到剪贴板（可以直接粘贴）'
} catch { }

Line ''
Line '------------------------------------------------'
Line ' 接下来在 GitHub 网页加 4 个 Secrets'
Line '------------------------------------------------'
Line ' 仓库 → Settings → Secrets and variables → Actions → New repository secret'
Line ''
Line '  1. BUILD_PROVISION_PROFILE_BASE64'
Line '     值 = 上面那个 FRAMECRAFT_PROFILE.b64 的全部内容（已在剪贴板）'
Line ''
Line '  2. BUILD_CERTIFICATE_BASE64'
Line '     值 = FRAMECRAFT_CERT.b64 的全部内容'
Line '         （在资源管理器里用记事本打开，Ctrl+A Ctrl+C）'
Line ''
Line '  3. P12_PASSWORD'
Line '     值 = 你导出 .p12 时设的那个密码'
Line '     ※ 不要发给任何人，也不要写进代码'
Line ''
Line '  4. KEYCHAIN_PASSWORD'
Line '     值 = 随便一串随机字符（比如 24 位字母数字），CI 只用它建临时钥匙串'
Line ''
if ($problems -gt 0) {
    Line "  注意：上面有 $problems 个问题，建议先修好再打包，否则 IPA 能出来但装不上"
    Line ''
}
Line ' 加完后：仓库 Actions → 左侧「iOS 签名打包」→ Run workflow'
Line ' 成功后在该次运行页面底部下载 FrameCraft-ipa 压缩包，里面就是 .ipa'
Line ''
Line 'Press any key to exit...'
try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { }

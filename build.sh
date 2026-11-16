#!/usr/bin/env bash
#
# FrameCraft 构建脚本 —— 直接产出可安装的 IPA
#
#   真机 IPA :  TEAM_ID=你的团队ID ./build.sh
#   仅验编译 :  ./build.sh --sim
#
set -euo pipefail

SCHEME="FrameCraft"
PROJECT="FrameCraft.xcodeproj"
CONFIG="${CONFIG:-Release}"
OUT="build"

# ---------- 模拟器编译校验（不需要签名） ----------
if [ "${1:-}" = "--sim" ]; then
  echo "==> 模拟器编译校验"
  xcodebuild -project "$PROJECT" \
             -scheme "$SCHEME" \
             -configuration Debug \
             -destination 'generic/platform=iOS Simulator' \
             -derivedDataPath "$OUT/DerivedData" \
             CODE_SIGNING_ALLOWED=NO \
             build | tail -n 40
  echo "==> 通过。产物在 $OUT/DerivedData/Build/Products/Debug-iphonesimulator/FrameCraft.app"
  exit 0
fi

# ---------- 真机 IPA ----------
TEAM="${TEAM_ID:-}"
if [ -z "$TEAM" ]; then
  cat <<'EOT'
未设置 TEAM_ID。

  TEAM_ID=ABCDE12345 ./build.sh

团队 ID 在 Apple Developer 后台 → Membership 里查看（10 位字母数字）。
若只想确认代码能编译，用：./build.sh --sim
EOT
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"

echo "==> 归档 (Release)"
xcodebuild -project "$PROJECT" \
           -scheme "$SCHEME" \
           -configuration "$CONFIG" \
           -destination 'generic/platform=iOS' \
           -archivePath "$OUT/FrameCraft.xcarchive" \
           -allowProvisioningUpdates \
           DEVELOPMENT_TEAM="$TEAM" \
           CODE_SIGN_STYLE=Automatic \
           archive

echo "==> 导出 IPA"
xcodebuild -exportArchive \
           -archivePath "$OUT/FrameCraft.xcarchive" \
           -exportPath "$OUT/ipa" \
           -exportOptionsPlist ExportOptions.plist \
           -allowProvisioningUpdates

echo ""
echo "==> 完成：$OUT/ipa/FrameCraft.ipa"
echo "    安装：Xcode → Window → Devices and Simulators → 拖入 .ipa"
echo "    或：  ios-deploy --bundle $OUT/ipa/FrameCraft.ipa"

#!/usr/bin/env bash
#
# PanghuGit 本地构建 + 安装脚本（无需 Apple 开发者账号）
#
# 用法：
#   scripts/local-install.sh              # 构建并安装到 /Applications
#   scripts/local-install.sh --skip-build # 跳过构建，仅安装已有产物
#
# 原理：
#   - CODE_SIGN_IDENTITY="-" 表示 ad-hoc 签名，无需任何证书
#   - entitlements 中的 $(TeamIdentifierPrefix) 替换为空串
#   - 本机可正常使用，Finder Sync 扩展可加载
#   - 其他设备需自行编译（ad-hoc 签名仅本机有效）
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

SKIP_BUILD=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1; shift ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done

SCHEME="PanghuGit"
CONFIG="Release"
DERIVED="$(mktemp -d)/DerivedData"
APP="$DERIVED/Build/Products/$CONFIG/PanghuGit.app"
APPEX="$APP/Contents/PlugIns/PanghuGitFinderSync.appex"

if [[ "$SKIP_BUILD" == "0" ]]; then
  echo "→ 生成 xcodeproj"
  xcodegen generate

  echo "→ 构建 $SCHEME ($CONFIG, ad-hoc 签名)"
  xcodebuild \
    -project PanghuGit.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED" \
    build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    DEVELOPMENT_TEAM=""

  echo "→ ad-hoc 签名（替换 entitlements 中的 TeamIdentifierPrefix）"
  APPEX_ENT="$(mktemp).plist"
  MAIN_ENT="$(mktemp).plist"
  sed 's/\$(TeamIdentifierPrefix)//g' "$ROOT/PanghuGitFinderSync/PanghuGitFinderSync.entitlements" > "$APPEX_ENT"
  sed 's/\$(TeamIdentifierPrefix)//g' "$ROOT/PanghuGit/PanghuGit.entitlements" > "$MAIN_ENT"
  codesign --force --sign - --entitlements "$APPEX_ENT" "$APPEX"
  codesign --force --sign - --entitlements "$MAIN_ENT" "$APP"
  rm -f "$APPEX_ENT" "$MAIN_ENT"
fi

echo "→ 安装到 /Applications"
if [[ -d /Applications/PanghuGit.app ]]; then
  echo "  移除旧版本"
  rm -rf /Applications/PanghuGit.app
fi
cp -R "$APP" /Applications/

echo "→ 清除隔离标记"
xattr -dr com.apple.quarantine /Applications/PanghuGit.app 2>/dev/null || true

echo "→ 注册 Finder Sync 扩展"
pluginkit -r -i com.lucy.panghugit.finder-sync 2>/dev/null || true
pluginkit -a /Applications/PanghuGit.app/Contents/PlugIns/PanghuGitFinderSync.appex 2>/dev/null || true
sleep 1
pluginkit -e use -i com.lucy.panghugit.finder-sync 2>/dev/null || true

echo "→ 重启 Finder"
killall Finder 2>/dev/null || true
sleep 2

echo "→ 弹出已挂载的旧 DMG 卷（避免从 DMG 启动）"
for vol in /Volumes/PanghuGit*; do
  if [[ -d "$vol" ]]; then
    hdiutil detach "$vol" -quiet 2>/dev/null || true
    echo "  已弹出 $vol"
  fi
done

echo "→ 清除 macOS 可能缓存的旧启动路径"
xattr -dr com.apple.quarantine /Applications/PanghuGit.app 2>/dev/null || true

echo "→ 清理 LaunchServices 旧注册（避免搜索框出现重复图标）"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
while IFS= read -r p; do
  [ -z "$p" ] && continue
  case "$p" in
    /Applications/PanghuGit.app*) continue ;;
  esac
  "$LSREGISTER" -u "$p" 2>/dev/null || true
done < <("$LSREGISTER" -dump 2>/dev/null | grep -i "panghugit" | grep "path:" | awk -F'path: *' '{print $2}' | awk -F' *[(]' '{print $1}' | sort -u)
"$LSREGISTER" -r -f /Applications/PanghuGit.app 2>/dev/null || true

echo "→ 启动 PanghuGit"
open /Applications/PanghuGit.app
sleep 2

echo ""
echo "✓ 安装并启动完成！"
echo "  如遇安全提示：系统设置 → 隐私与安全性 → 点击「仍要打开」"
echo "  在 WelcomeView 点击「启用扩展」后，Finder 右键即可看到 PanghuGit 菜单"

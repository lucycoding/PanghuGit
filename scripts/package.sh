#!/usr/bin/env bash
#
# PanghuGit 打包脚本：生成 .xcodeproj → 构建 Release → 签名 → 公证 → 打 DMG
#
# 用法：
#   scripts/package.sh                              # minimal（依赖系统 git），跳过签名
#   scripts/package.sh --sign                       # 走签名 + 公证
#   scripts/package.sh --variant full               # full（内置 git，零依赖）
#   scripts/package.sh --variant full --sign        # full + 签名
#   scripts/package.sh --variant minimal --sign     # 显式 minimal + 签名
#
# 产物：
#   minimal → dist/PanghuGit-<ver>.dmg
#   full    → dist/PanghuGit-<ver>-full.dmg
#
# 签名/公证所需环境变量：
#   PANGHUGIT_DEVELOPMENT_TEAM      Apple Developer Team ID（如 "ABC123DEF4"）
#   PANGHUGIT_NOTARY_USER           Apple ID
#   PANGHUGIT_NOTARY_PASSWORD        app-specific password
#   PANGHUGIT_NOTARY_TEAM_SHORT      短团队名（可选）
#   PANGHUGIT_BUNDLE_ID              默认 com.lucy.panghugit
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
echo "→ ROOT=$ROOT"

DO_SIGN=0
VARIANT="minimal"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign) DO_SIGN=1; shift ;;
    --variant) VARIANT="$2"; shift 2 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done

BUNDLE_ID="${PANGHUGIT_BUNDLE_ID:-com.lucy.panghugit}"
SCHEME="PanghuGit"
CONFIG="Release"
DERIVED="$(mktemp -d)/DerivedData"
APP="$DERIVED/Build/Products/$CONFIG/PanghuGit.app"
# 从 project.yml 读取 MARKETING_VERSION，回退到环境变量或 1.0.0
VERSION="$(grep 'MARKETING_VERSION:' "$ROOT/project.yml" | sed 's/.*: *"\(.*\)"/\1/' || true)"
if [[ -z "$VERSION" ]]; then
  VERSION="${MARKETING_VERSION:-1.0.0}"
fi

# DMG 文件名按 variant 区分
if [[ "$VARIANT" == "full" ]]; then
  DMG_DIST="dist/PanghuGit-$VERSION-full.dmg"
else
  DMG_DIST="dist/PanghuGit-$VERSION.dmg"
fi

echo "→ variant=$VARIANT  → 产物=$DMG_DIST"

# full: 先下载便携 git 到 bundle Resources
if [[ "$VARIANT" == "full" ]]; then
  echo "→ full 模式：注入内置 git"
  if [[ ! -d "$ROOT/PanghuGit/Resources/git/bin" ]]; then
    echo "  内置 git 不存在，运行 fetch_git.sh …"
    scripts/fetch_git.sh
  else
    echo "  内置 git 已存在，跳过下载"
  fi
else
  echo "→ minimal 模式：不注入内置 git（依赖系统 git）"
  # 确保 Resources/git 为空（避免残留）
  rm -rf "$ROOT/PanghuGit/Resources/git/bin" \
         "$ROOT/PanghuGit/Resources/git/libexec" \
         "$ROOT/PanghuGit/Resources/git/share" 2>/dev/null || true
fi

echo "→ 生成 xcodeproj"
xcodegen generate

echo "→ 构建 $SCHEME ($CONFIG)"
xcodebuild \
  -project PanghuGit.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  build

if [[ "$DO_SIGN" == "1" ]]; then
  echo "→ 签名 & 公证"
  : "${PANGHUGIT_DEVELOPMENT_TEAM:?需要 PANGHUGIT_DEVELOPMENT_TEAM}"
  : "${PANGHUGIT_NOTARY_USER:?需要 PANGHUGIT_NOTARY_USER}"
  : "${PANGHUGIT_NOTARY_PASSWORD:?需要 PANGHUGIT_NOTARY_PASSWORD}"

  APPEX="$APP/Contents/PlugIns/PanghuGitFinderSync.appex"
  codesign --force --sign "Developer ID Application: $PANGHUGIT_DEVELOPMENT_TEAM" \
    --entitlements "$ROOT/PanghuGitFinderSync/PanghuGitFinderSync.entitlements" \
    "$APPEX"
  codesign --force --sign "Developer ID Application: $PANGHUGIT_DEVELOPMENT_TEAM" \
    --entitlements "$ROOT/PanghuGit/PanghuGit.entitlements" \
    "$APP"

  ZIP="$(mktemp -d)/PanghuGit.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" \
    --apple-id "$PANGHUGIT_NOTARY_USER" \
    --password "$PANGHUGIT_NOTARY_PASSWORD" \
    ${PANGHUGIT_NOTARY_TEAM_SHORT:+--team-id "$PANGHUGIT_NOTARY_TEAM_SHORT"} \
    --wait
  xcrun stapler staple "$APP"
  echo "→ 公证与 staple 完成"
  spctl -a -vv -t exec "$APP" || true
else
  echo "→ 跳过签名/公证（本地验证）"
  APPEX="$APP/Contents/PlugIns/PanghuGitFinderSync.appex"
  APPEX_ENT="$(mktemp).plist"
  MAIN_ENT="$(mktemp).plist"
  sed 's/\$(TeamIdentifierPrefix)//g' "$ROOT/PanghuGitFinderSync/PanghuGitFinderSync.entitlements" > "$APPEX_ENT"
  sed 's/\$(TeamIdentifierPrefix)//g' "$ROOT/PanghuGit/PanghuGit.entitlements" > "$MAIN_ENT"
  codesign --force --sign - --entitlements "$APPEX_ENT" "$APPEX"
  codesign --force --sign - --entitlements "$MAIN_ENT" "$APP"
  rm -f "$APPEX_ENT" "$MAIN_ENT"
fi

echo "→ 打 DMG：$DMG_DIST"
mkdir -p dist
rm -f "$DMG_DIST"
DMG_STAGING="$(mktemp -d)"
ln -s /Applications "$DMG_STAGING/Applications"
cp -R "$APP" "$DMG_STAGING/"
# 清掉 staging 区的 com.apple.quarantine，避免分发出去的 App 自带隔离属性导致
# 在用户机器上扩展不可加载（未签名 DMG 的常见根因）。
xattr -dr com.apple.quarantine "$DMG_STAGING/PanghuGit.app" 2>/dev/null || true
hdiutil create -volname "PanghuGit" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_DIST"
# 生成的 DMG 自身也清一遍（避免 Gatekeeper 提示引入新的隔离属性上游链）
xattr -dr com.apple.quarantine "$DMG_DIST" 2>/dev/null || true
rm -rf "$DMG_STAGING"

echo "✓ 完成：$DMG_DIST"
echo "  体积：$(du -sh "$DMG_DIST" | awk '{print $1}')"
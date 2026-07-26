#!/usr/bin/env bash
#
# 下载并解压便携版 git 到 PanghuGit/Resources/git/，供 App bundle 内置使用。
#
# 用法：
#   scripts/fetch_git.sh                          # 默认下载源
#   scripts/fetch_git.sh --url <URL>              # 自定义下载 URL
#   scripts/fetch_git.sh --url <URL> --sha256 <h> # 自定义 URL + SHA256 校验
#   scripts/fetch_git.sh --clean                  # 清理已下载内容
#
# 默认下载源：git-osx-installer 提供的预构建 git（Universal）。
# 如需切换到其他便携 git（如自己构建的 universal binary），用 --url 指定。
#
# 注意：内置 git 会让 DMG 体积增大约 50-80MB。仅在需要"零依赖"分发时使用；
# 默认分发可不运行此脚本，PanghuGit 会回退到系统 /usr/bin/git。
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEST="$ROOT/PanghuGit/Resources/git"

DEFAULT_URL="https://sourceforge.net/projects/git-osx-installer/files/git-2.33.0-intel-universal-mavericks.dmg/download"
DEFAULT_SHA256=""  # 留空则跳过校验（自定义 --url 时需配套 --sha256）

CLEAN=0
URL="$DEFAULT_URL"
EXPECTED_SHA256="$DEFAULT_SHA256"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean) CLEAN=1; shift ;;
    --url) URL="$2"; shift 2 ;;
    --sha256) EXPECTED_SHA256="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ "$CLEAN" == "1" ]]; then
  rm -rf "$DEST"
  echo "✓ 已清理 $DEST"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ 下载: $URL"
curl -fL "$URL" -o "$TMP/git.dmg"

# 完整性校验
if [[ -n "$EXPECTED_SHA256" ]]; then
  ACTUAL="$(shasum -a 256 "$TMP/git.dmg" | awk '{print $1}')"
  if [[ "$ACTUAL" != "$EXPECTED_SHA256" ]]; then
    echo "✗ SHA256 校验失败！" >&2
    echo "  期望: $EXPECTED_SHA256" >&2
    echo "  实际: $ACTUAL" >&2
    exit 1
  fi
  echo "✓ SHA256 校验通过"
else
  echo "::warning::未指定 --sha256，跳过完整性校验。建议配套使用以保证安全。" >&2
fi

echo "→ 挂载 DMG"
MNT_DIR="$(mktemp -d /tmp/panghu-git-dmg.XXXXXX)"
MNT="$(hdiutil attach "$TMP/git.dmg" -nobrowse -noautoopen -mountpoint "$MNT_DIR" 2>/dev/null | awk '/mountpoint/ {print $NF}' | head -1)"
[[ -z "$MNT" ]] && MNT="$MNT_DIR"

PKG="$(find "$MNT" -name "*.pkg" -maxdepth 2 2>/dev/null | head -1)"
if [[ -z "$PKG" ]]; then
  echo "未在 DMG 中找到 .pkg" >&2
  hdiutil detach "$MNT" -quiet || true
  exit 1
fi

echo "→ 解包 pkg: $PKG"
xar -xf "$PKG" -C "$TMP"
PAYLOAD="$(find "$TMP" -name "Payload" -maxdepth 3 | head -1)"
if [[ -z "$PAYLOAD" ]]; then
  echo "未找到 Payload" >&2
  hdiutil detach "$MNT" -quiet || true
  exit 1
fi

echo "→ 解压 Payload"
( cd "$TMP" && cpio -i < "$PAYLOAD" 2>/dev/null )

echo "→ 提取 git 到 $DEST"
rm -rf "$DEST"
mkdir -p "$DEST"
# git-osx-installer 把 git 装到 /usr/local/git
SRC="$TMP/usr/local/git"
if [[ ! -d "$SRC" ]]; then
  echo "解包后未找到 /usr/local/git" >&2
  hdiutil detach "$MNT" -quiet || true
  exit 1
fi
# 仅复制运行所需：bin + libexec + share（git 需要这些子命令）
cp -R "$SRC/bin" "$DEST/bin"
cp -R "$SRC/libexec" "$DEST/libexec"
cp -R "$SRC/share" "$DEST/share"

hdiutil detach "$MNT" -quiet || true

echo "✓ 内置 git 就位于 $DEST"
echo "  体积：$(du -sh "$DEST" | awk '{print $1}')"
echo ""
echo "构建时 xcodegen 会把 PanghuGit/Resources 纳入 copy bundle resources；"
echo "运行期 GitLocator.bundledGit() 将解析到 Contents/Resources/git/bin/git。"
#!/usr/bin/env bash
#
# 校验 Casks/panghugit.rb 语法，并在有 DMG 时计算/填充 sha256。
#
# 用法：
#   scripts/verify_cask.sh                      # 仅语法检查
#   scripts/verify_cask.sh --fill dist/PanghuGit-0.1.0.dmg   # 计算并写入 sha256
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
CASK="$ROOT/Casks/panghugit.rb"

FILL=""
DMG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fill) FILL=1; shift; DMG="${1:-}"; shift ;;
    *) shift ;;
  esac
done

echo "→ 检查 cask 语法：$CASK"
if command -v brew &>/dev/null; then
  if brew cask style "$CASK" 2>/dev/null; then
    echo "✓ brew cask style 通过"
  else
    echo "⚠ brew cask style 有警告（可忽略，非阻塞）"
  fi
  # audit 需要网络且 url 可达，此处仅做语法加载
  ruby -c "$CASK" 2>/dev/null && echo "✓ Ruby 语法通过" || {
    echo "✗ Ruby 语法错误" >&2; exit 1
  }
else
  # 无 brew 时用 ruby 直接校验语法
  if ruby -c "$CASK" 2>/dev/null; then
    echo "✓ Ruby 语法通过（未安装 brew，跳过 cask style）"
  else
    echo "✗ Ruby 语法错误" >&2
    exit 1
  fi
fi

# 填充 sha256
if [[ "$FILL" == "1" ]]; then
  if [[ -z "$DMG" || ! -f "$DMG" ]]; then
    echo "✗ 需要指定 DMG 路径：--fill dist/PanghuGit-x.y.z.dmg" >&2
    exit 2
  fi
  HASH="$(shasum -a 256 "$DMG" | awk '{print $1}')"
  echo "→ sha256: $HASH"
  # 替换 cask 中的 sha256 行
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/sha256 :no_check/sha256 \"$HASH\"/" "$CASK"
  else
    sed -i "s/sha256 :no_check/sha256 \"$HASH\"/" "$CASK"
  fi
  echo "✓ 已写入 sha256 到 $CASK"
fi
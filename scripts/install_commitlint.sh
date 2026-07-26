#!/usr/bin/env bash
#
# 安装 PanghuGit Conventional Commits commit-msg hook。
#
# 用法：
#   scripts/install_commitlint.sh           # 装到当前仓库 .git/hooks/commit-msg
#   scripts/install_commitlint.sh --global  # 装到全局 core.hooksPath 目录
#   scripts/install_commitlint.sh --uninstall
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_SRC="$SCRIPT_DIR/commitlint.sh"

GLOBAL=0
UNINSTALL=0

for arg in "$@"; do
  case "$arg" in
    --global) GLOBAL=1 ;;
    --uninstall) UNINSTALL=1 ;;
  esac
done

if [[ "$UNINSTALL" == "1" ]]; then
  if [[ "$GLOBAL" == "1" ]]; then
    HOOK_DIR="$(git config --global core.hooksPath 2>/dev/null || true)"
    if [[ -n "$HOOK_DIR" && -f "$HOOK_DIR/commit-msg" ]]; then
      rm -f "$HOOK_DIR/commit-msg"
      echo "✓ 已删除全局 commit-msg hook：$HOOK_DIR/commit-msg"
    fi
  else
    if [[ -f "$ROOT/.git/hooks/commit-msg" ]]; then
      rm -f "$ROOT/.git/hooks/commit-msg"
      echo "✓ 已删除仓库 commit-msg hook"
    fi
  fi
  exit 0
fi

if [[ "$GLOBAL" == "1" ]]; then
  HOOK_DIR="$HOME/.git-hooks"
  mkdir -p "$HOOK_DIR"
  cp "$HOOK_SRC" "$HOOK_DIR/commit-msg"
  chmod +x "$HOOK_DIR/commit-msg"
  git config --global core.hooksPath "$HOOK_DIR"
  echo "✓ 全局 commit-msg hook → $HOOK_DIR/commit-msg"
  echo "  git config --global core.hooksPath = $HOOK_DIR"
else
  HOOK_DIR="$ROOT/.git/hooks"
  if [[ ! -d "$HOOK_DIR" ]]; then
    echo "✗ 当前目录不是 git 仓库（无 .git/hooks）" >&2
    exit 1
  fi
  cp "$HOOK_SRC" "$HOOK_DIR/commit-msg"
  chmod +x "$HOOK_DIR/commit-msg"
  echo "✓ 仓库 commit-msg hook → $HOOK_DIR/commit-msg"
fi

echo ""
echo "试运行（校验一条消息）："
echo "  echo 'feat: test message' | bash $HOOK_SRC /dev/stdin"
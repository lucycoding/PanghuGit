#!/usr/bin/env bash
#
# 将 `panghugit` 安装为指向 PanghuGit.app 主可执行的符号链接，从而：
#   panghugit commit <repo>
#   panghugit branch <repo>
#
# 用法：
#   scripts/install_cli.sh                       # 安装到 /usr/local/bin/panghugit
#   scripts/install_cli.sh /some/path/bin        # 安装到自定义目录
#   scripts/install_cli.sh --completion          # 同时安装 shell tab-completion
#   scripts/install_cli.sh --uninstall          # 删除 symlink + completion
#
set -euo pipefail

APP_DEFAULT="/Applications/PanghuGit.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

UNINSTALL=0
COMPLETION=0
BIN_DIR="/usr/local/bin"
APP="$APP_DEFAULT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall) UNINSTALL=1; shift ;;
    --completion) COMPLETION=1; shift ;;
    --app) APP="$2"; shift 2 ;;
    --no-cli) shift ;;
    *) BIN_DIR="$1"; shift ;;
  esac
done

mkdir -p "$BIN_DIR"

LINK="$BIN_DIR/panghugit"

# --- 卸载 ---
if [[ "$UNINSTALL" == "1" ]]; then
  if [[ -L "$LINK" ]]; then
    rm -f "$LINK"
    echo "✓ 已删除 $LINK"
  else
    echo "$LINK 不是 symlink，跳过"
  fi
  for f in ~/.zsh/completion/_panghugit /etc/bash_completion.d/panghugit \
           ~/.zsh/completion/_macgit /etc/bash_completion.d/macgit; do
    if [[ -f "$f" ]]; then rm -f "$f"; echo "✓ 已删除 $f"; fi
  done
  exit 0
fi

# --- 安装 CLI symlink ---
TARGET="$APP/Contents/MacOS/PanghuGit"
if [[ ! -x "$TARGET" ]]; then
  echo "未找到可执行：$TARGET" >&2
  echo "请先将 PanghuGit.app 拖入 /Applications 或通过 --app 指定路径。" >&2
  exit 1
fi

ln -sfn "$TARGET" "$LINK"
echo "✓ $LINK -> $TARGET"

# --- 安装 completion ---
if [[ "$COMPLETION" == "1" ]]; then
  ZSH_COMP_DIR="$HOME/.zsh/completion"
  mkdir -p "$ZSH_COMP_DIR"
  cp "$ROOT/completion/zsh/_panghugit" "$ZSH_COMP_DIR/_panghugit"
  echo "✓ zsh completion → $ZSH_COMP_DIR/_panghugit"
  echo "  确保 ~/.zshrc 含：fpath+=$ZSH_COMP_DIR && compinit"

  BASH_COMP_DIR="/etc/bash_completion.d"
  if [[ -d "$BASH_COMP_DIR" ]] || [[ -w /etc ]]; then
    sudo cp "$ROOT/completion/bash/panghugit.bash" "$BASH_COMP_DIR/panghugit" 2>/dev/null \
      && echo "✓ bash completion → $BASH_COMP_DIR/panghugit" \
      || echo "⚠ 无法写入 $BASH_COMP_DIR（可手动 cp completion/bash/panghugit.bash 到 ~/.bash_completion.d/）"
  else
    mkdir -p "$HOME/.bash_completion.d"
    cp "$ROOT/completion/bash/panghugit.bash" "$HOME/.bash_completion.d/panghugit"
    echo "✓ bash completion → $HOME/.bash_completion.d/panghugit"
  fi
fi

echo ""
echo "请确认 $BIN_DIR 已在你的 PATH 中。"
echo "    echo \$PATH | tr ':' '\n' | grep -F '$BIN_DIR'"
echo ""
echo "试运行："
echo "    panghugit version"

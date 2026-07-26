#!/usr/bin/env bash
#
# PanghuGit Conventional Commits 校验脚本（commit-msg hook）。
#
# 校验规则：
#   <type>[(<scope>)]: <subject>
#   type ∈ feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert
#   subject 非空，长度 ≤ 72 字符
#   允许 ! 表示 breaking change（如 feat!): ...）
#   允许合并提交、回滚提交（Merge:/Revert:）跳过校验
#
# 安装：
#   scripts/install_commitlint.sh          # 装到 .git/hooks/commit-msg
#   scripts/install_commitlint.sh --global # 装到 git config --global core.hooksPath
#
set -euo pipefail

# commit-msg 文件路径由 git 传入 $1
MSG_FILE="${1:-}"
if [[ -z "$MSG_FILE" || ! -f "$MSG_FILE" ]]; then
  echo "commitlint: 未收到 commit-msg 文件" >&2
  exit 1
fi

# 读取第一行非注释、非空行
FIRST_LINE=""
while IFS= read -r line; do
  # 跳过注释行（# 开头）和空行
  trimmed="${line#"${line%%[![:space:]]*}"}"
  if [[ -z "$trimmed" || "$trimmed" == \#* ]]; then
    continue
  fi
  FIRST_LINE="$trimmed"
  break
done < "$MSG_FILE"

if [[ -z "$FIRST_LINE" ]]; then
  echo "✗ commitlint: 提交信息为空" >&2
  exit 1
fi

# 跳过 Merge / Revert 提交
if [[ "$FIRST_LINE" == Merge* || "$FIRST_LINE" == Revert* ]]; then
  exit 0
fi

# Conventional Commits 正则
# 允许格式：type[(scope)][!]: subject
PATTERN='^(feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert)(\([^)]+\))?!?: .+'

if [[ ! "$FIRST_LINE" =~ $PATTERN ]]; then
  echo "✗ commitlint: 提交信息不符合 Conventional Commits 格式" >&2
  echo "" >&2
  echo "  期望格式：<type>[(<scope>)][!]: <subject>" >&2
  echo "  实际首行：$FIRST_LINE" >&2
  echo "" >&2
  echo "  可用 type：feat fix docs style refactor perf test chore build ci revert" >&2
  echo "  示例：feat: 添加 Blame 面板" >&2
  echo "        fix(core): 修复角标刷新竞态" >&2
  echo "        feat!: 移除旧 API（breaking change）" >&2
  exit 1
fi

# subject 长度校验（取 type[(scope)][!]: 之后的部分）
if [[ "$FIRST_LINE" =~ ^[^:]+:\ (.+)$ ]]; then
  SUBJECT="${BASH_REMATCH[1]}"
else
  SUBJECT="$FIRST_LINE"
fi
if [[ ${#SUBJECT} -gt 72 ]]; then
  echo "⚠ commitlint: subject 长度 ${#SUBJECT} > 72 字符（建议精简）" >&2
  echo "  subject: $SUBJECT" >&2
  # 警告但不阻断
fi

exit 0
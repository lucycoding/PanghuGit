#!/usr/bin/env bash
#
# 校验已下载的 PanghuGit DMG 与 GitHub Release 公布的 SHA256 是否一致，
# 防止镜像篡改或传输损坏。
#
# 用法：
#   scripts/verify_checksum.sh <dmg> <expected_sha256>
#   scripts/verify_checksum.sh <dmg> --from-release <url>   # 从 Release 资产 SHA256SUMS.txt 拉取
#
# 退出码：
#   0 = 校验通过
#   1 = 校验失败（哈希不匹配）
#   2 = 参数错误 / 网络失败
#
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "用法：verify_checksum.sh <dmg> <sha256 | --from-release <url>]" >&2
  exit 2
fi

DMG="$1"
MODE="$2"

if [[ ! -f "$DMG" ]]; then
  echo "✗ 文件不存在：$DMG" >&2
  exit 2
fi

# 计算实际哈希
ACTUAL="$(shasum -a 256 "$DMG" | awk '{print $1}')"
echo "→ 文件：$DMG"
echo "→ SHA256：$ACTUAL"

EXPECTED=""

if [[ "$MODE" == "--from-release" ]]; then
  if [[ -z "${3:-}" ]]; then
    echo "✗ --from-release 需要提供 SHA256SUMS.txt 的 URL" >&2
    exit 2
  fi
  SUMS_URL="$3"
  BASENAME="$(basename "$DMG")"
  echo "→ 从 $SUMS_URL 拉取校验值…"
  EXPECTED="$(curl -sfL "$SUMS_URL" | awk -v b="$BASENAME" '$2 == b {print $1; exit}' || true)"
  if [[ -z "$EXPECTED" ]]; then
    echo "✗ 在 $SUMS_URL 中未找到 $BASENAME 的校验行" >&2
    exit 2
  fi
else
  EXPECTED="$MODE"
fi

echo "→ 期望：$EXPECTED"
echo ""

if [[ "$ACTUAL" == "$EXPECTED" ]]; then
  echo "✓ 校验通过"
  exit 0
else
  echo "✗ 校验失败：哈希不匹配" >&2
  echo "  实际：$ACTUAL" >&2
  echo "  期望：$EXPECTED" >&2
  exit 1
fi
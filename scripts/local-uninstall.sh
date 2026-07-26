#!/usr/bin/env bash
#
# PanghuGit 本地卸载脚本：彻底移除本机所有 PanghuGit 相关文件
#
# 用法：
#   scripts/local-uninstall.sh
#
set -euo pipefail

echo "→ 退出 PanghuGit"
killall PanghuGit 2>/dev/null || true
sleep 1

echo "→ 禁用并移除 Finder Sync 扩展"
pluginkit -e disable -i com.lucy.panghugit.finder-sync 2>/dev/null || true
pluginkit -r -i com.lucy.panghugit.finder-sync 2>/dev/null || true
sleep 1

echo "→ 反注册 LaunchServices（清除应用搜索缓存）"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u /Applications/PanghuGit.app 2>/dev/null || true
while IFS= read -r p; do
  [ -z "$p" ] && continue
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$p" 2>/dev/null || true
done < <(/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump 2>/dev/null | grep -i "panghugit" | grep "path:" | awk -F'path: *' '{print $2}' | awk -F' *[(]' '{print $1}' | sort -u)
rm -rf ~/Library/LaunchAgents/com.lucy.panghugit.* 2>/dev/null || true
echo "  已清理"

echo "→ 删除 /Applications/PanghuGit.app"
rm -rf /Applications/PanghuGit.app 2>/dev/null && echo "  已删除" || echo "  不存在，跳过"

echo "→ 删除 CLI 符号链接"
rm -f /usr/local/bin/panghugit /usr/local/bin/macgit 2>/dev/null && echo "  已删除" || echo "  不存在，跳过"

echo "→ 删除 Shell 自动补全"
rm -f ~/.zsh/completion/_panghugit ~/.zsh/completion/_macgit 2>/dev/null
rm -f /etc/bash_completion.d/panghugit /etc/bash_completion.d/macgit 2>/dev/null
rm -f ~/.bash_completion.d/panghugit ~/.bash_completion.d/macgit 2>/dev/null
echo "  已清理"

echo "→ 删除偏好与缓存"
rm -rf ~/Library/Preferences/com.lucy.panghugit.plist \
       ~/Library/Application\ Support/com.lucy.panghugit \
       ~/Library/Caches/com.lucy.panghugit \
       ~/Library/Group\ Containers/group.com.lucy.panghugit \
       ~/Library/Saved\ Application\ State/com.lucy.panghugit.savedState \
       2>/dev/null && echo "  已清理" || echo "  无残留"

echo "→ 删除 Xcode DerivedData"
rm -rf ~/Library/Developer/Xcode/DerivedData/PanghuGit-* 2>/dev/null && echo "  已清理" || echo "  无残留"

echo "→ 弹出已挂载的 DMG 卷"
for vol in /Volumes/PanghuGit*; do
  if [[ -d "$vol" ]]; then
    hdiutil detach "$vol" -quiet 2>/dev/null || true
    echo "  已弹出 $vol"
  fi
done

echo "→ 重启 Finder"
killall Finder 2>/dev/null || true
sleep 2

echo ""
echo "✓ PanghuGit 已彻底卸载"

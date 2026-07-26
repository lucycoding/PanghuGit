cask "panghugit" do
  version "1.0.0"
  sha256 "<fill-after-release>"

  url "https://github.com/lucycoding/PanghuGit/releases/download/v#{version}/PanghuGit-#{version}.dmg"
  name "PanghuGit"
  desc "macOS Finder right-click Git tools"
  homepage "https://github.com/lucycoding/PanghuGit"

  livecheck do
    url "https://github.com/lucycoding/PanghuGit/releases.atom"
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "PanghuGit.app"

  caveats do
    puts ""
    puts "  启用 Finder 扩展："
    puts "    系统设置 → 隐私与安全性 → 扩展 → Finder 扩展 → 勾选 PanghuGit"
    puts ""
    puts "  首次运行如遇安全提示（未公证版本）："
    puts "    系统设置 → 隐私与安全性 → 点击「仍要打开」"
    puts "    或终端执行：xattr -dr com.apple.quarantine /Applications/PanghuGit.app"
    puts ""
  end

  zap trash: [
    "~/Library/Preferences/com.lucy.panghugit.plist",
    "~/Library/Application Support/com.lucy.panghugit",
    "~/Library/Caches/com.lucy.panghugit",
    "~/Library/Containers/com.lucy.panghugit.finder-sync",
    "~/Library/Group Containers/group.com.lucy.panghugit",
    "~/Library/Saved Application State/com.lucy.panghugit.savedState",
  ]
end

class Panghugit < Formula
  desc "macOS Finder right-click Git tools"
  homepage "https://github.com/lucycoding/PanghuGit"
  url "https://github.com/lucycoding/PanghuGit/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "<fill-after-release>"
  license "MIT"
  version "1.0.0"

  depends_on "xcodegen" => :build
  depends_on :xcode => ["15.0", :build]
  depends_on :macos => :ventura

  def install
    system "xcodegen", "generate"
    xcodebuild_args = %w[
      build
      -project PanghuGit.xcodeproj
      -scheme PanghuGit
      -configuration Release
      -destination generic/platform=macOS
      CODE_SIGN_IDENTITY=-
      CODE_SIGNING_REQUIRED=NO
      DEVELOPMENT_TEAM=
    ]
    system "xcodebuild", *xcodebuild_args,
           "DERIVED_DATA_PATH=build",
           "BUILD_DIR=build"

    app_path = "build/Build/Products/Release/PanghuGit.app"
    appec_path = "#{app_path}/Contents/PlugIns/PanghuGitFinderSync.appex"

    tmp_ent_appex = Tempfile.new(["appex", ".plist"])
    tmp_ent_main = Tempfile.new(["main", ".plist"])
    begin
      appex_ent = File.read("PanghuGitFinderSync/PanghuGitFinderSync.entitlements")
      main_ent = File.read("PanghuGit/PanghuGit.entitlements")
      tmp_ent_appex.write(appex_ent.gsub("$(TeamIdentifierPrefix)", ""))
      tmp_ent_main.write(main_ent.gsub("$(TeamIdentifierPrefix)", ""))
      tmp_ent_appex.close
      tmp_ent_main.close
      system "codesign", "--force", "--sign", "-", "--entitlements", tmp_ent_appex.path, appec_path
      system "codesign", "--force", "--sign", "-", "--entitlements", tmp_ent_main.path, app_path
    ensure
      tmp_ent_appex.unlink
      tmp_ent_main.unlink
    end

    system "xattr", "-dr", "com.apple.quarantine", app_path

    prefix.install app_path
  end

  def post_install
    appex = "#{prefix}/PanghuGit.app/Contents/PlugIns/PanghuGitFinderSync.appex"
    system "pluginkit", "-a", appex
    system "pluginkit", "-e", "use", "-i", "com.lucy.panghugit.finder-sync"
  end

  def caveats
    <<~EOS
      启用 Finder 扩展：
        系统设置 → 隐私与安全性 → 扩展 → Finder 扩展 → 勾选 PanghuGit

      首次运行如遇安全提示：
        系统设置 → 隐私与安全性 → 点击「仍要打开」

      安装命令行 panghugit：
        #{prefix}/PanghuGit.app/Contents/MacOS/PanghuGit --help
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{prefix}/PanghuGit.app/Contents/MacOS/PanghuGit version 2>/dev/null")
  end
end

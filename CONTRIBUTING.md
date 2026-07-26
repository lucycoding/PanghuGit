# Contributing to PanghuGit

[English](./CONTRIBUTING.en.md) | 中文

感谢你对 PanghuGit 的关注！欢迎提交 Issue、Pull Request 和建议。

## 开发环境搭建

### 前置要求

- macOS 13.0 (Ventura) 及以上
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`
- [SwiftLint](https://github.com/realm/SwiftLint)（可选）：`brew install swiftlint`

### 快速开始

```bash
git clone https://github.com/lucycoding/PanghuGit.git
cd panghu-git

# 生成 Xcode 工程
xcodegen generate

# 用 Xcode 打开
open PanghuGit.xcodeproj

# 或一键构建安装到本机验证
./scripts/local-install.sh
```

## 开发流程

1. Fork 本仓库
2. 从 `main` 创建功能分支：`git checkout -b feat/your-feature`
3. 编码 + 编写测试
4. 确保通过所有检查（见下方）
5. 提交更改，使用 Conventional Commits 格式
6. 推送并创建 Pull Request

## 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
<type>(<scope>): <description>

[optional body]
```

### Type

| Type | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `docs` | 文档变更 |
| `refactor` | 重构（不改变功能） |
| `test` | 测试相关 |
| `chore` | 构建/工具/依赖变更 |
| `perf` | 性能优化 |
| `style` | 代码格式（不影响逻辑） |

### Scope（可选）

- `commit` / `log` / `diff` / `sync` / `branch` / `stash` / `tag` / `merge` / `settings` — 对应功能视图
- `finder` — Finder Sync 扩展
- `shared` — Shared 层
- `cli` — 命令行
- `ci` — CI/CD

### 示例

```
feat(commit): add hunk-level staging support
fix(sync): resolve pullRebase state persistence issue
docs: update README with installation instructions
refactor(shared): extract GitTaskHelper for structured concurrency
```

## 代码规范

### Swift

- 遵循 [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- 运行 SwiftLint 检查：`swiftlint lint`
- 自动修正：`swiftlint --fix`
- 优先使用 `struct`，仅在需要引用语义或 `NSObject` 子类时使用 `class`
- 优先使用 Swift 并发（`async/await`、`Task`）而非 completion handler
- 避免强制解包 `!`，使用 `guard let` / `if let` / `??`

### Shell 脚本

- 所有脚本使用 `set -euo pipefail`
- 通过 ShellCheck 检查：`shellcheck scripts/*.sh`

### 本地化

- 所有用户可见字符串必须通过 `L10n.s()` / `L10n.f()` 引用
- 新增 key 需同时添加到 `zh-Hans.lproj/Localizable.strings` 和 `en.lproj/Localizable.strings`

## 项目架构

```
panghu-git/
├── Shared/                    # App + Extension 共享代码（解析器、业务逻辑）
├── PanghuGit/                 # 主应用（SwiftUI，非沙盒）
├── PanghuGitFinderSync/       # Finder Sync 扩展（沙盒）
├── Tests/PanghuGitTests/      # 单元测试
└── scripts/                   # 构建/安装/打包脚本
```

### 关键约束

- **Finder Sync 扩展运行在沙盒中**，不能直接执行 Git 命令
- **主 App 与扩展通过 `panghugit://` URL Scheme 通信**
- **共享数据通过 App Group UserDefaults**（suite name: `com.lucy.panghugit`）
- **扩展内 `L10n` 必须从主 App bundle 加载**（自动 walk up from `.appex` to `.app`）

## 测试

```bash
# 运行全部测试
xcodebuild test -project PanghuGit.xcodeproj \
                -scheme PanghuGit \
                -destination 'platform=macOS' \
                -only-testing:PanghuGitTests
```

- 新功能必须包含对应的单元测试
- Parser 和逻辑代码放在 `Shared/` 以确保可测试性
- 视图逻辑测试提取为独立的 `*LogicTests.swift`

## PR 审核流程

1. 自动 CI 检查必须通过（Build + Test + ShellCheck + SwiftLint）
2. 至少一名维护者 Review
3. 解决所有 Review 意见后 Merge

## 发布流程

> 仅维护者操作。正式发布需付费 Apple 开发者账号用于签名公证；未签名版本也可发布（用户首次运行需手动允许）。

### 1. 打 Tag 触发自动发布

```bash
git tag v1.0.0
git push origin v1.0.0
```

推送 `v*` tag 后，`release.yml` workflow 自动执行：
- 生成 xcodeproj → 构建 minimal / full 两种 DMG
- 若配置了签名 secrets 则签名公证，否则发布未签名版本
- 生成 `SHA256SUMS.txt` 并上传到 GitHub Release

### 2. 回填 Homebrew Cask / Formula 的 sha256

Release 完成后，CI 会输出 `::notice::` 提醒。手动操作：

```bash
# 从 GitHub Release 下载 SHA256SUMS.txt，或本地计算
shasum -a 256 PanghuGit-1.0.0.dmg
# 输出形如：a1b2c3...  PanghuGit-1.0.0.dmg

# 更新 Casks/panghugit.rb 与 Formula/panghugit.rb：
#   version "1.0.0"
#   sha256 "a1b2c3..."
```

### 3. 更新 homebrew-tap 仓库

```bash
# 在 github.com/lucycoding/homebrew-tap 仓库中
# 复制更新后的 Casks/panghugit.rb 与 Formula/panghugit.rb
# 提交 PR 并合并
```

### 4. 更新 CHANGELOG

在 `CHANGELOG.md` 与 `CHANGELOG.en.md` 中新增对应版本条目。

### 5. 验证安装

```bash
# 验证 Homebrew 安装
brew tap lucycoding/tap https://github.com/lucycoding/homebrew-tap
brew install panghugit
# 或
brew install --cask panghugit
```

## 报告问题

- Bug 报告：使用 [Bug Report 模板](https://github.com/lucycoding/PanghuGit/issues/new?template=bug_report.yml)
- 功能建议：使用 [Feature Request 模板](https://github.com/lucycoding/PanghuGit/issues/new?template=feature_request.yml)
- 安全漏洞：请参阅 [SECURITY.md](./SECURITY.md)

# 开发者指南

> [English](./DEVELOPER-GUIDE.en.md) | 中文

本文档面向 PanghuGit 的贡献者，帮助你快速搭建开发环境并理解项目架构。

## 开发环境

### 前置要求

| 要求 | 版本 |
|------|------|
| macOS | 13.0 (Ventura) 及以上 |
| Xcode | 15+ |
| Swift | 5.5+ |
| xcodegen | `brew install xcodegen` |
| SwiftLint（可选） | `brew install swiftlint` |

### 首次设置

```bash
git clone https://github.com/lucycoding/PanghuGit.git
cd panghu-git

# 生成 Xcode 工程
xcodegen generate

# 打开 Xcode
open PanghuGit.xcodeproj
```

### 本地构建安装

```bash
# 一键构建 + ad-hoc 签名 + 安装到 /Applications
./scripts/local-install.sh

# 卸载
./scripts/local-uninstall.sh
```

## 架构概览

```
┌─────────────────────────────────────────────────────┐
│                    macOS Finder                      │
│  ┌──────────────────┐    ┌────────────────────────┐ │
│  │  Finder Sync     │    │   主 App (SwiftUI)     │ │
│  │  Extension       │───▶│                        │ │
│  │  (沙盒)          │URL │   GitRunner ──────────▶│ git CLI
│  │                  │    │                        │ │
│  │  - 右键菜单      │    │   CommitView           │ │
│  │  - 文件角标      │    │   LogView              │ │
│  │                  │    │   DiffView             │ │
│  └──────────────────┘    │   ...                  │ │
│                          └────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### 三层架构

| 层 | 目录 | 说明 |
|----|------|------|
| **Shared** | `Shared/` | 主 App 和 Finder Sync 扩展共享的代码：Git CLI 封装、解析器、业务逻辑、设置存储 |
| **Main App** | `PanghuGit/` | SwiftUI 应用，非沙盒，执行所有 Git 操作 |
| **Finder Sync** | `PanghuGitFinderSync/` | 沙盒扩展，提供右键菜单和文件角标 |

### 进程间通信

| 通信方式 | 方向 | 用途 |
|----------|------|------|
| `panghugit://` URL Scheme | 扩展 → 主 App | 唤起功能窗口（commit、log、diff 等） |
| App Group UserDefaults | 双向 | 共享设置（语言、Git 路径、菜单样式等） |
| DistributedNotificationCenter | 主 App → 扩展 | 通知扩展刷新角标 |

### 关键约束

1. **Finder Sync 扩展运行在沙盒中**，不能直接执行 Git 命令
2. **主 App 非沙盒**（Git 操作需要文件系统访问权限）
3. **共享代码必须放在 `Shared/` 目录**，两个 target 都引用此目录
4. **扩展内 `L10n` 必须从主 App bundle 加载**（自动 walk up from `.appex` to `.app`）
5. **所有用户可见字符串必须通过 `L10n.s()` / `L10n.f()` 引用**

## Git 路径解析

PanghuGit 通过 `GitLocator` 四级回退解析 git 可执行文件：

1. `SettingsStore.gitPath`（用户显式指定）
2. PATH 中的 `git`（`which git`）
3. `/usr/bin/git`（Xcode CLT）
4. App bundle 内 `Contents/Resources/git/bin/git`（可选内置）

## 测试

### 运行测试

```bash
xcodebuild test -project PanghuGit.xcodeproj \
                -scheme PanghuGit \
                -destination 'platform=macOS' \
                -only-testing:PanghuGitTests
```

### 测试策略

- **Parser 测试**：所有 Git 输出解析器都有对应的单元测试（GitStatusParser、LogQuery、BranchQuery 等）
- **Logic 测试**：视图逻辑提取到独立函数进行测试（CommitViewLogicTests、SyncViewLogicTests）
- **可测试性原则**：业务逻辑放在 `Shared/` 而非 View 中，确保可独立测试

### 添加新测试

1. 在 `Tests/PanghuGitTests/` 创建 `*Tests.swift` 文件
2. 使用 `XCTestCase` + `XCTest` 方法
3. 测试 parser/logic 代码，不测试 UI

## 本地化

### 添加新的本地化 Key

1. 在 `PanghuGit/zh-Hans.lproj/Localizable.strings` 添加中文
2. 在 `PanghuGit/en.lproj/Localizable.strings` 添加英文
3. 代码中使用 `L10n.s("your.key")` 或 `L10n.f("your.key", arg)`

### 语言切换

用户可在设置中切换语言，`SettingsStore.applyLanguage()` 会设置 `AppleLanguages`。

## 构建

### Debug 构建

```bash
xcodegen generate
xcodebuild -project PanghuGit.xcodeproj \
           -scheme PanghuGit \
           -configuration Debug \
           -destination 'platform=macOS' \
           build CODE_SIGN_IDENTITY="-" \
                 CODE_SIGNING_REQUIRED=NO
```

### Release 构建 + DMG

```bash
# 无签名 DMG
./scripts/package.sh

# 签名 + 公证 DMG
PANGHUGIT_DEVELOPMENT_TEAM=ABC123 \
PANGHUGIT_NOTARY_USER=you@apple.id \
PANGHUGIT_NOTARY_PASSWORD=app-specific-password \
./scripts/package.sh --sign
```

## 调试技巧

### 查看应用日志

```bash
log show --predicate 'subsystem == "com.lucy.panghugit"' --last 5m
```

### 调试 Finder Sync 扩展

1. 在 Xcode 中选择 `PanghuGitFinderSync` scheme
2. 运行（会附加到 Finder 进程）
3. 或使用 `pluginkit -e use -i com.lucy.panghugit.findersync` 手动启用扩展

### 清理扩展注册

```bash
pluginkit -e ignore -i com.lucy.panghugit.findersync
killall Finder
```

## 代码规范

- 遵循 [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- 运行 `swiftlint lint` 检查代码风格
- 使用 Conventional Commits 提交格式
- 详见 [CONTRIBUTING.md](./CONTRIBUTING.md)

# Developer Guide

This document is for PanghuGit contributors, helping you quickly set up your development environment and understand the project architecture.

## Development Environment

### Prerequisites

| Requirement | Version |
|-------------|---------|
| macOS | 13.0 (Ventura) or later |
| Xcode | 15+ |
| Swift | 5.5+ |
| xcodegen | `brew install xcodegen` |
| SwiftLint (optional) | `brew install swiftlint` |

### Initial Setup

```bash
git clone https://github.com/lucycoding/PanghuGit.git
cd PanghuGit

# Generate Xcode project
xcodegen generate

# Open in Xcode
open PanghuGit.xcodeproj
```

### Local Build & Install

```bash
# One-click build + ad-hoc sign + install to /Applications
./scripts/local-install.sh

# Uninstall
./scripts/local-uninstall.sh
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                    macOS Finder                      │
│  ┌──────────────────┐    ┌────────────────────────┐ │
│  │  Finder Sync     │    │   Main App (SwiftUI)   │ │
│  │  Extension       │───▶│                        │ │
│  │  (Sandboxed)     │URL │   GitRunner ──────────▶│ git CLI
│  │                  │    │                        │ │
│  │  - Context menu  │    │   CommitView           │ │
│  │  - File badges   │    │   LogView              │ │
│  │                  │    │   DiffView             │ │
│  └──────────────────┘    │   ...                  │ │
│                          └────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### Three-Layer Architecture

| Layer | Directory | Description |
|-------|-----------|-------------|
| **Shared** | `Shared/` | Code shared between Main App and Finder Sync Extension: Git CLI wrappers, parsers, business logic, settings storage |
| **Main App** | `PanghuGit/` | SwiftUI application, non-sandboxed, executes all Git operations |
| **Finder Sync** | `PanghuGitFinderSync/` | Sandboxed extension, provides context menu and file badges |

### Inter-Process Communication

| Method | Direction | Purpose |
|--------|-----------|---------|
| `panghugit://` URL Scheme | Extension → Main App | Launch feature windows (commit, log, diff, etc.) |
| App Group UserDefaults | Bidirectional | Share settings (language, Git path, menu style, etc.) |
| DistributedNotificationCenter | Main App → Extension | Notify extension to refresh badges |

### Key Constraints

1. **Finder Sync Extension runs in a sandbox**, cannot directly execute Git commands
2. **Main App is non-sandboxed** (Git operations require file system access)
3. **Shared code must be in the `Shared/` directory**, referenced by both targets
4. **Extension `L10n` must load from Main App bundle** (auto walks up from `.appex` to `.app`)
5. **All user-visible strings must be referenced via `L10n.s()` / `L10n.f()`**

## Git Path Resolution

PanghuGit resolves the git executable via `GitLocator` with a 4-level fallback:

1. `SettingsStore.gitPath` (user-specified)
2. `git` in PATH (`which git`)
3. `/usr/bin/git` (Xcode CLT)
4. App bundle `Contents/Resources/git/bin/git` (optional bundled)

## Testing

### Running Tests

```bash
xcodebuild test -project PanghuGit.xcodeproj \
                -scheme PanghuGit \
                -destination 'platform=macOS' \
                -only-testing:PanghuGitTests
```

### Testing Strategy

- **Parser tests**: All Git output parsers have corresponding unit tests (GitStatusParser, LogQuery, BranchQuery, etc.)
- **Logic tests**: View logic is extracted into standalone functions for testing (CommitViewLogicTests, SyncViewLogicTests)
- **Testability principle**: Business logic belongs in `Shared/` rather than Views, ensuring independent testability

### Adding New Tests

1. Create a `*Tests.swift` file in `Tests/PanghuGitTests/`
2. Use `XCTestCase` + `XCTest` methods
3. Test parser/logic code, not UI

## Localization

### Adding a New Localization Key

1. Add Chinese string in `PanghuGit/zh-Hans.lproj/Localizable.strings`
2. Add English string in `PanghuGit/en.lproj/Localizable.strings`
3. Reference in code with `L10n.s("your.key")` or `L10n.f("your.key", arg)`

### Language Switching

Users can switch languages in Settings; `SettingsStore.applyLanguage()` sets `AppleLanguages`.

## Building

### Debug Build

```bash
xcodegen generate
xcodebuild -project PanghuGit.xcodeproj \
           -scheme PanghuGit \
           -configuration Debug \
           -destination 'platform=macOS' \
           build CODE_SIGN_IDENTITY="-" \
                 CODE_SIGNING_REQUIRED=NO
```

### Release Build + DMG

```bash
# Unsigned DMG
./scripts/package.sh

# Signed + notarized DMG
PANGHUGIT_DEVELOPMENT_TEAM=ABC123 \
PANGHUGIT_NOTARY_USER=you@apple.id \
PANGHUGIT_NOTARY_PASSWORD=app-specific-password \
./scripts/package.sh --sign
```

## Debugging Tips

### View Application Logs

```bash
log show --predicate 'subsystem == "com.lucy.panghugit"' --last 5m
```

### Debug Finder Sync Extension

1. Select `PanghuGitFinderSync` scheme in Xcode
2. Run (attaches to Finder process)
3. Or manually enable extension: `pluginkit -e use -i com.lucy.panghugit.findersync`

### Clean Extension Registration

```bash
pluginkit -e ignore -i com.lucy.panghugit.findersync
killall Finder
```

## Code Standards

- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Run `swiftlint lint` to check code style
- Use Conventional Commits format for commits
- See [CONTRIBUTING.md](./CONTRIBUTING.md) for details

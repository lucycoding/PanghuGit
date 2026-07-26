# Contributing to PanghuGit

Thank you for your interest in PanghuGit! Issues, Pull Requests, and suggestions are all welcome.

## Development Environment Setup

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- [SwiftLint](https://github.com/realm/SwiftLint) (optional): `brew install swiftlint`

### Quick Start

```bash
git clone https://github.com/lucycoding/PanghuGit.git
cd PanghuGit

# Generate Xcode project
xcodegen generate

# Open in Xcode
open PanghuGit.xcodeproj

# Or one-click build & install for local verification
./scripts/local-install.sh
```

## Development Workflow

1. Fork this repository
2. Create a feature branch from `main`: `git checkout -b feat/your-feature`
3. Code + write tests
4. Ensure all checks pass (see below)
5. Commit changes using Conventional Commits format
6. Push and create a Pull Request

## Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>

[optional body]
```

### Type

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation change |
| `refactor` | Refactor (no behavior change) |
| `test` | Test related |
| `chore` | Build/tool/dependency change |
| `perf` | Performance improvement |
| `style` | Code formatting (no logic change) |

### Scope (optional)

- `commit` / `log` / `diff` / `sync` / `branch` / `stash` / `tag` / `merge` / `settings` — corresponding feature views
- `finder` — Finder Sync Extension
- `shared` — Shared layer
- `cli` — Command-line
- `ci` — CI/CD

### Examples

```
feat(commit): add hunk-level staging support
fix(sync): resolve pullRebase state persistence issue
docs: update README with installation instructions
refactor(shared): extract GitTaskHelper for structured concurrency
```

## Code Standards

### Swift

- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Run SwiftLint: `swiftlint lint`
- Auto-fix: `swiftlint --fix`
- Prefer `struct`; use `class` only when reference semantics or `NSObject` subclass is needed
- Prefer Swift concurrency (`async/await`, `Task`) over completion handlers
- Avoid force unwrap `!`; use `guard let` / `if let` / `??`

### Shell Scripts

- All scripts must use `set -euo pipefail`
- Check with ShellCheck: `shellcheck scripts/*.sh`

### Localization

- All user-visible strings must be referenced via `L10n.s()` / `L10n.f()`
- New keys must be added to both `zh-Hans.lproj/Localizable.strings` and `en.lproj/Localizable.strings`

## Project Architecture

```
PanghuGit/
├── Shared/                    # App + Extension shared code (parsers, business logic)
├── PanghuGit/                 # Main application (SwiftUI, non-sandboxed)
├── PanghuGitFinderSync/       # Finder Sync Extension (sandboxed)
├── Tests/PanghuGitTests/      # Unit tests
└── scripts/                   # Build/Install/Package scripts
```

### Key Constraints

- **Finder Sync Extension runs in a sandbox**, cannot directly execute Git commands
- **Main App and Extension communicate via `panghugit://` URL Scheme**
- **Shared data via App Group UserDefaults** (suite name: `com.lucy.panghugit`)
- **Extension `L10n` must load from Main App bundle** (auto walks up from `.appex` to `.app`)

## Testing

```bash
# Run all tests
xcodebuild test -project PanghuGit.xcodeproj \
                -scheme PanghuGit \
                -destination 'platform=macOS' \
                -only-testing:PanghuGitTests
```

- New features must include corresponding unit tests
- Parser and logic code should be placed in `Shared/` for testability
- View logic tests should be extracted into standalone `*LogicTests.swift` files

## PR Review Process

1. Automated CI checks must pass (Build + Test + ShellCheck + SwiftLint)
2. At least one maintainer review
3. Resolve all review comments before merge

## Release Process

> Maintainers only. Official releases require a paid Apple Developer account for signing/notarization; unsigned builds can also be published (users must manually allow on first launch).

### 1. Tag to trigger automatic release

```bash
git tag v1.0.0
git push origin v1.0.0
```

Pushing a `v*` tag triggers the `release.yml` workflow which:
- Generates xcodeproj → builds minimal / full DMG variants
- Signs and notarizes if secrets are configured, otherwise publishes unsigned
- Generates `SHA256SUMS.txt` and uploads to GitHub Release

### 2. Backfill Homebrew Cask / Formula sha256

After release, CI emits a `::notice::` reminder. Manual steps:

```bash
# Download SHA256SUMS.txt from GitHub Release, or compute locally
shasum -a 256 PanghuGit-1.0.0.dmg
# Output: a1b2c3...  PanghuGit-1.0.0.dmg

# Update Casks/panghugit.rb and Formula/panghugit.rb:
#   version "1.0.0"
#   sha256 "a1b2c3..."
```

### 3. Update homebrew-tap repo

```bash
# In github.com/lucycoding/homebrew-tap
# Copy updated Casks/panghugit.rb and Formula/panghugit.rb
# Submit PR and merge
```

### 4. Update CHANGELOG

Add a new entry in `CHANGELOG.md` and `CHANGELOG.en.md`.

### 5. Verify installation

```bash
brew tap lucycoding/tap https://github.com/lucycoding/homebrew-tap
brew install panghugit
# or
brew install --cask panghugit
```

## Reporting Issues

- Bug reports: Use the [Bug Report template](https://github.com/lucycoding/PanghuGit/issues/new?template=bug_report.yml)
- Feature requests: Use the [Feature Request template](https://github.com/lucycoding/PanghuGit/issues/new?template=feature_request.yml)
- Security vulnerabilities: See [SECURITY.md](./SECURITY.md)

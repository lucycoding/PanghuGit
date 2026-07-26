# PanghuGit

<p align="center">
  <img src="PanghuGit/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="PanghuGit Icon">
</p>

<p align="center">
  <strong>macOS Finder Context Menu Git Tool</strong>
</p>

<p align="center">
  <a href="https://github.com/lucycoding/PanghuGit/actions/workflows/ci.yml"><img src="https://github.com/lucycoding/PanghuGit/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/lucycoding/PanghuGit/releases"><img src="https://img.shields.io/github/v/release/lucycoding/PanghuGit?include_prereleases" alt="Release"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/github/license/lucycoding/PanghuGit" alt="License"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.5-orange" alt="Swift">
</p>

<p align="center">
  <a href="#installation">Install</a> · <a href="#features">Features</a> · <a href="#building">Build</a> · <a href="#architecture">Architecture</a> · <a href="#contributing">Contribute</a>
</p>

<p align="center">
  <a href="./README.md">中文</a> | English
</p>

---

## Overview

PanghuGit is a macOS Finder context menu Git tool. Right-click in Finder to perform everyday Git operations — no terminal or Git GUI needed.

**Highlights:**

- Pure native Swift + SwiftUI, zero external dependencies
- Finder Sync Extension integration: context menu + file badges
- Full Git workflow coverage: commit, push, branch, merge, rebase, conflict resolution, blame, submodule, worktree, bisect, and more
- Bilingual UI (Chinese + English), one-click switch in Settings
- CLI mode `panghugit` with tab-completion

## Screenshots

| Finder Context Menu | Commit View |
|:---:|:---:|
| ![Finder Context Menu](docs/screenshots/en/finder-menu-en.png) | ![Commit View](docs/screenshots/en/commit-view-en.png) |
| **Log View** | **Diff View** |
| ![Log View](docs/screenshots/en/log-view-en.png) | ![Diff View](docs/screenshots/en/diff-view-en.png) |
| **Language Settings** | **Keyboard Shortcuts** |
| ![Language Settings](docs/screenshots/en/settings-language-en.png) | ![Keyboard Shortcuts](docs/screenshots/en/shortcuts-en.png) |

> [More screenshots →](docs/USER-MANUAL.en.md)

## Features

### Finder Context Menu

Right-click any directory in Finder to access:

```
PanghuGit ▶
  Git Commit…           Commit changes (Hunk-level staging / Amend / Signoff / Conventional Commits)
  Git Sync…             Pull / Push / Fetch (--prune / --tags / --rebase / --force-with-lease)
  ─────────────────
  Git Log…              Commit history (Branch sidebar + progressive loading + Diff highlight + Cherry-pick)
  Git Diff              Working tree diff (Syntax highlighting + Hunk-level staging)
  Git Modifications…    Modified files overview
  ─────────────────
  Git Switch…           Switch branch / Checkout commit (Auto-stash dirty working tree)
  Git Branch Manager…   Branch management (Create / Delete / Rename / Create from commit)
  Git Stash…            Stash management (Per-file browsing / --keep-index / Stash branch)
  Git Tags…             Tag management
  Git Merge / Rebase…   Merge / Rebase
  Git Revert / Reset…   Revert / Reset (Undo last commit / Soft / Mixed / Hard)
  ─────────────────
  Git Init Here         Initialize repo in current directory
  Git Clone…            Clone remote repository
  Git Add to .gitignore Add ignore rules
  Git Blame…            Line-by-line blame (Breadcrumb navigation + Previous revision jump)
  Git Submodule…        Submodule management (Sync / Update all)
  Git Worktree…         Worktree management
  Git Patch…            Patch create / apply / preview / Dry Run
  Git Export…           Archive export (git archive)
  Git Cleanup…          Clean untracked files (git clean)
  Git Bisect…           Binary search (Good/Bad/Skip + Output parsing)
  Git Reflog…           Reference log
  Git Repo Settings…    Repo-level config (Config editing / Hooks management)
  Git Settings…         Global settings
```

### Key Features

| Feature | Description |
|---|---|
| **Finder Badges** | Automatic file status badges (Modified/Added/Deleted/Untracked/Conflict/Ignored) |
| **Hunk-level Staging** | Stage or unstage individual hunks in Commit/Diff views, no need to stage entire files |
| **3-way Conflict Resolution** | Ours / Base / Theirs three-column diff, per-block selection, manual edit mode, FileMerge integration |
| **Progressive Log Loading** | Loads 7 days by default, "Load More" appends 50 entries, avoids timeouts on large repos |
| **Cherry-pick** | Multi-select commits in Log view for batch Cherry-pick |
| **Diff Syntax Highlighting** | Added lines green, deleted lines red, file headers purple, hunk headers blue |
| **Branch Sidebar** | Local + remote branch list, click to filter Log view |
| **Conventional Commits** | Built-in feat/fix/docs and 8 more type quick-select, customizable templates |
| **Author Autocomplete** | Commit view Author field with live filtering from git log history, Top 5 suggestions |
| **Diff Tool Integration** | Built-in DiffView / FileMerge (opendiff) / vimdiff / Custom tool |
| **Keyboard Shortcuts** | ⌘↩ Commit / ⌘⇧↩ Commit & Push / ⌘⇧S Stage / ⌘⌥S Unstage / ⌘R Refresh and more |
| **Bilingual UI** | Full Chinese + English interface, one-click switch in Settings |
| **panghugit CLI** | Command-line mode with tab-completion (zsh + bash) |
| **Menu Style** | Submenu mode (default) or flat mode, switchable in Settings |
| **Terminal Integration** | Choose Terminal / iTerm2 / Warp as default terminal |
| **Git Path 4-level Fallback** | User-specified → PATH → /usr/bin/git → App-bundled git |

### Keyboard Shortcuts

| Shortcut | Action | View |
|----------|--------|------|
| ⌘↩ | Commit | Commit |
| ⌘⇧↩ | Commit & Push | Commit |
| ⌘⇧S | Stage selected | Commit |
| ⌘⌥S | Unstage selected | Commit |
| ⌘⇧A | Toggle Amend | Commit |
| ⌘/ | Toggle Skip Hooks | Commit |
| ⌘R | Refresh | All views |
| ⌘C | Copy SHA | Log |
| ⌘⌥C | Copy commit message | Log |
| ⌘P | Pull | Sync |

## Installation

### Option 1: Build from Source (Recommended, no Apple Developer account needed)

```bash
# 1. Clone the repository
git clone https://github.com/lucycoding/PanghuGit.git
cd PanghuGit

# 2. One-click build + install (ad-hoc signed, works locally)
./scripts/local-install.sh
```

The script automatically: generates xcodeproj → compiles Release → ad-hoc signs → installs to `/Applications` → registers Finder extension → restarts Finder.

### Option 2: Homebrew (builds from source)

```bash
# Add tap
brew tap lucycoding/tap https://github.com/lucycoding/homebrew-tap

# Install (auto-compiles)
brew install panghugit
```

### Option 3: Download DMG (requires paid Apple Developer account for signing & notarization)

> **Note**: Unsigned DMGs will be blocked by macOS Gatekeeper. If you don't have a paid Apple Developer account, use Option 1 or 2 instead.

```bash
# After download, drag to /Applications
# On first launch, go to System Settings → Privacy & Security → click "Open Anyway"
# Or run in terminal:
xattr -dr com.apple.quarantine /Applications/PanghuGit.app
```

### First Launch

1. Open `/Applications/PanghuGit.app`
2. If you see a security prompt, go to **System Settings → Privacy & Security** → click "Open Anyway"
3. In WelcomeView, click **"Enable Extension"** and confirm in the system dialog
4. If the context menu still doesn't appear, click **"Restart Finder"** or run `killall Finder` in terminal
5. Right-click any directory in Finder to see the `PanghuGit ▶` menu

> ⚠️ **Do not run directly from the DMG** — macOS App Translocation prevents the Finder Sync extension from registering.

### Uninstall

```bash
./scripts/local-uninstall.sh
```

Cleans up: App, Finder Sync extension registration, Preferences, Caches, Group Containers.

## Building

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- [SwiftLint](https://github.com/realm/SwiftLint) (optional): `brew install swiftlint`

### Command-line Build

```bash
# Generate xcodeproj
xcodegen generate

# Build (skip signing, for local verification)
xcodebuild -project PanghuGit.xcodeproj \
           -scheme PanghuGit \
           -configuration Release \
           -destination 'generic/platform=macOS' \
           build CODE_SIGN_IDENTITY="-" \
                 CODE_SIGNING_REQUIRED=NO \
                 DEVELOPMENT_TEAM=""
```

### Local Install

```bash
# One-click build + install (recommended)
./scripts/local-install.sh

# Skip build, install existing artifact only
./scripts/local-install.sh --skip-build
```

### Package DMG (requires paid Apple Developer account)

```bash
# Local verification (skip signing/notarization)
./scripts/package.sh

# Sign + notarize
PANGHUGIT_DEVELOPMENT_TEAM=ABC123 \
PANGHUGIT_NOTARY_USER=you@apple.id \
PANGHUGIT_NOTARY_PASSWORD=app-specific-password \
./scripts/package.sh --sign
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    macOS Finder                      │
│                                                     │
│  ┌──────────────────┐    ┌────────────────────────┐ │
│  │  Finder Sync     │    │   Main App (SwiftUI)   │ │
│  │  Extension       │───▶│                        │ │
│  │  (Sandboxed)     │URL │   CommitView           │ │
│  │                  │    │   LogView              │ │
│  │  - Context menu  │    │   DiffView             │ │
│  │  - File badges   │    │   SwitchView           │ │
│  │                  │    │   SettingsView          │ │
│  └──────────────────┘    │   ...                  │ │
│                          │                        │ │
│                          │   GitRunner ──────────▶│ git CLI
│                          └────────────────────────┘ │
└─────────────────────────────────────────────────────┘

Communication: panghugit:// URL Scheme + App Group UserDefaults + DistributedNotificationCenter
```

### Key Design

| Component | Description |
|---|---|
| **Finder Sync Extension** | Sandboxed process, provides context menu and file badges; launches Main App via `panghugit://` URL Scheme |
| **Main App** | Non-sandboxed, executes all Git operations; receives URL events via `NSAppleEventManager` |
| **App Group** | `com.lucy.panghugit` UserDefaults suite, shared settings between Main App and Extension |
| **GitRunner** | Git CLI wrapper with timeout control; path resolved via `GitLocator` 4-level fallback |
| **GitDirResolver** | Resolves .git directory, supports worktree's `gitdir:` file pointers |
| **GitTaskHelper** | Structured concurrency wrapper, unified `Task` + `GitRunner` call pattern |
| **L10n** | Extension loads localized strings from Main App bundle (walks up from .appex to .app) |

### Git Path Resolution Priority

1. User-specified `gitPath` in Settings
2. `git` in PATH (`which git`)
3. `/usr/bin/git` (Xcode CLT)
4. App bundle `Contents/Resources/git/bin/git` (optional bundled, zero-dependency distribution)

## Directory Structure

```
PanghuGit/
├── Shared/                          # Shared source (Main App + Extension, 23 files)
│   ├── GitRunner.swift              # Git CLI wrapper (timeout/output capture)
│   ├── GitLocator.swift             # Git path 4-level fallback resolution
│   ├── GitTaskHelper.swift          # Structured concurrency wrapper
│   ├── GitStatusParser.swift        # git status --porcelain parser
│   ├── LogQuery.swift               # git log parser (progressive loading)
│   ├── BranchQuery.swift            # Branch list query
│   ├── MergeQuery.swift             # Merge conflict detection
│   ├── ConflictParser.swift         # 3-way merge conflict parser
│   ├── HunkParser.swift             # Diff hunk parser + patch builder
│   ├── DiffLineRenderer.swift       # Diff line type classifier
│   ├── GitDirResolver.swift         # .git directory resolver (worktree support)
│   ├── CommitArgsBuilder.swift      # Commit argument builder
│   ├── CommitFileStatus.swift       # Commit file status enum
│   ├── StashTagQueries.swift        # Stash/Tag queries
│   ├── BlameSubmoduleRepoConfig.swift # Blame/Submodule/Config queries
│   ├── RepoProbe.swift              # Repository root detection
│   ├── SettingsStore.swift          # App Group shared settings
│   ├── L10n.swift                   # Localization (auto-resolves Main App bundle in extension)
│   ├── PanghuGitAction.swift        # URL Scheme action definitions
│   ├── StatusBadge.swift            # Badge icon mapping
│   ├── StatusBarView.swift          # Unified status bar component
│   ├── EmptyStateView.swift         # Empty state component
│   └── BisectOutputParser.swift     # Bisect output parser
├── PanghuGit/                       # Main application (SwiftUI, non-sandboxed)
│   ├── PanghuGitApp.swift           # App entry point
│   ├── AppDelegate.swift            # NSAppleEventManager + Menu bar
│   ├── HostWindowController.swift   # Independent window management (960×600)
│   ├── ActionRouter.swift           # URL scheme router
│   ├── CLI.swift                    # Command-line interface
│   ├── BundleDiagnostics.swift      # Install self-check + auto-fix
│   ├── CommitView.swift             # Commit view (main structure)
│   ├── CommitChangesList.swift      # Commit - changes list
│   ├── CommitDiffPane.swift         # Commit - Diff pane
│   ├── CommitEditorSection.swift    # Commit - message editor
│   ├── CommitActions.swift          # Commit - action methods
│   ├── LogView.swift                # Log view (branch sidebar + progressive loading)
│   ├── DiffView.swift               # Diff view (syntax highlighting)
│   ├── SyncView.swift               # Pull / Push / Fetch
│   ├── SwitchView.swift             # Branch switch
│   ├── BranchManagerView.swift      # Branch management
│   ├── StashView.swift              # Stash management
│   ├── TagView.swift                # Tag management
│   ├── MergeRebaseView.swift        # Merge / Rebase
│   ├── ConflictResolverView.swift   # Conflict resolution
│   ├── ConflictDetailView.swift     # 3-way conflict detail
│   ├── RevertResetView.swift        # Revert / Reset
│   ├── InitCloneView.swift          # Init / Clone
│   ├── IgnoreView.swift             # .gitignore management
│   ├── BlameView.swift              # Blame view
│   ├── SubmoduleView.swift          # Submodule management
│   ├── WorktreeView.swift           # Worktree management
│   ├── BisectView.swift             # Bisect
│   ├── ReflogView.swift             # Reflog
│   ├── PatchView.swift              # Patch create / apply
│   ├── ExportView.swift             # Archive export
│   ├── CleanupView.swift            # Clean untracked
│   ├── ModificationsView.swift      # Modifications overview
│   ├── SettingsView.swift           # Settings (General/Git/Language/Ignore/Commit)
│   ├── RepoSettingsView.swift               # Repo-level config
│   ├── WelcomeView.swift            # Welcome page
│   ├── ShortcutsView.swift          # Keyboard shortcuts reference
│   ├── CommitPickerView.swift       # Commit picker
│   ├── en.lproj/                    # English localization
│   ├── zh-Hans.lproj/               # Chinese localization
│   └── Assets.xcassets/             # Icon assets
├── PanghuGitFinderSync/             # Finder Sync Extension (sandboxed)
│   ├── FinderSync.swift             # Context menu + badge registration
│   ├── BadgeWatcher.swift           # Background git status monitoring
│   └── Assets.xcassets/             # Extension icons
├── Tests/PanghuGitTests/            # Unit tests (23 files, 163 tests)
├── scripts/                         # Build / Install / Package scripts
│   ├── local-install.sh             # One-click local build & install
│   ├── local-uninstall.sh           # Uninstall
│   ├── package.sh                   # DMG packaging
│   ├── install_cli.sh               # CLI install
│   ├── fetch_git.sh                 # Download portable git
│   ├── commitlint.sh                # Commit message lint
│   ├── install_commitlint.sh        # Install commitlint hook
│   ├── verify_cask.sh               # Homebrew Cask verification
│   └── verify_checksum.sh           # DMG checksum
├── completion/                      # Shell completion scripts
│   ├── zsh/_panghugit
│   └── bash/panghugit.bash
├── Formula/panghugit.rb             # Homebrew Formula (builds from source)
├── Casks/panghugit.rb               # Homebrew Cask (pre-built DMG)
├── docs/                            # Documentation
│   ├── USER-MANUAL.md               # User manual
│   └── DEVELOPER-GUIDE.md           # Developer guide
├── .github/workflows/               # CI/CD
│   ├── ci.yml                       # Continuous integration
│   └── release.yml                  # Auto release
└── project.yml                      # xcodegen project definition
```

## Command Line (panghugit CLI)

The PanghuGit main executable also supports argv mode:

```bash
# Install as panghugit command
./scripts/install_cli.sh

# Usage
panghugit version
panghugit log /path/to/repo --oneline -n 10
panghugit diff /path/to/repo --staged
panghugit open commit /path/to/repo    # Launch GUI commit window
```

| Command | Description |
|---|---|
| `panghugit version` | Print version |
| `panghugit which <path>` | Print repository root path |
| `panghugit branch <path>` | List branches |
| `panghugit log <path> [--author\|--branch\|--since\|-n\|--oneline\|--graph]` | Commit history |
| `panghugit diff <path> [--staged\|--HEAD\|<a> <b>] [-- <file>]` | Diff output |
| `panghugit show <path> <ref> [--stat\|--patch]` | Commit details |
| `panghugit open <action> <path>` | Launch GUI |

## Testing

```bash
# Run all tests
xcodebuild test -project PanghuGit.xcodeproj \
                -scheme PanghuGit \
                -destination 'platform=macOS' \
                -only-testing:PanghuGitTests
```

163 unit tests, covering:

| Test File | Coverage |
|---|---|
| `GitStatusParserTests` | git status --porcelain parsing |
| `GitFileStatusTests` | File status enum + badge mapping |
| `CommitFileStatusTests` | Commit file status + icon mapping |
| `LogQueryEntryParsingTests` | git log output parsing |
| `BranchQueryParsingTests` | branch --list output parsing |
| `DiffViewLineParsingTests` | Diff patch line type classification |
| `HunkParserTests` | Diff hunk parsing |
| `HunkParserExtendedTests` | Hunk edge cases (empty hunk / binary diff) |
| `ConflictParserTests` | 3-way merge conflict marker parsing |
| `BisectOutputParserTests` | Bisect output parsing |
| `WorktreeViewTests` | Worktree list parsing |
| `MergeQueryTests` | Conflict XY marker detection |
| `SubmoduleQueryTests` | .gitmodules parsing |
| `RepoProbeTests` | Repository root detection |
| `SettingsStoreTests` | Settings enum values + template serialization |
| `PanghuGitURLSchemeTests` | URL Scheme encoding/decoding |
| `ActionRouterTests` / `ActionRouterIdTests` | URL Scheme routing |
| `CommitViewLogicTests` | Commit view logic |
| `SyncViewLogicTests` | Sync view logic |
| `GitErrorMessageTests` | Friendly error message mapping |
| `GitListResultTests` | GitListResult enum behavior |
| `RepoConfigQueryTests` | Repo config query parsing |

## Signing & Notarization

| Scenario | Method | Paid Apple Developer Account Required? |
|---|---|---|
| Open source on GitHub | Push code directly | **No** |
| Personal daily use | `local-install.sh` ad-hoc signing | **No** |
| Other users install from source | Homebrew Formula / `local-install.sh` | **No** |
| Upload pre-built DMG | Developer ID signing + Apple notarization | **Yes** |

**You can fully use and open-source this project without a paid Apple Developer account.** Source distribution + local ad-hoc signing for personal use + Homebrew formula for community users is the zero-cost optimal approach.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed development workflow and guidelines.

Quick start:

1. Fork this repository
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Commit your changes (use [Conventional Commits](https://www.conventionalcommits.org/) format)
4. Push the branch: `git push origin feat/your-feature`
5. Create a Pull Request

Developer guide: [docs/DEVELOPER-GUIDE.md](./docs/DEVELOPER-GUIDE.md)

## License

[MIT License](./LICENSE)

# Changelog

[English](./CHANGELOG.en.md) | 中文

## v1.0.0 (2026-07-23)

### Core Features (F-01~F-18)

- Finder right-click menu with 20+ Git operations
- File status badges (modified/added/deleted/untracked/conflict/ignored)
- Commit with Conventional Commits template (11 types)
- Push / Pull / Fetch with advanced options
- Log view with branch sidebar + progressive loading
- Diff view with syntax highlighting
- Branch switch / create / delete / rename
- Merge / Rebase
- Stash create / apply / pop / drop
- Tag create / delete
- Clone / Init
- .gitignore management
- Git settings (global + repo-level)
- Welcome page with extension enable + Finder restart

### Power User Features (G-01~G-28)

- G-01 Amend Commit with force-with-lease safety
- G-02 Hunk-level staging with HunkParser
- G-03 Force Push / Push with Lease with confirmation dialog
- G-04 --no-verify Skip Hooks toggle
- G-05 Keyboard Shortcuts (⌘↩ Commit, ⌘⇧↩ Commit & Push, ⌘⇧S Stage, ⌘⌥S Unstage, ⌘R Refresh, ⌘C Copy SHA, ⌘P Pull)
- G-06 Fetch --prune
- G-07 Push --tags
- G-08 Pull with --rebase (persisted preference)
- G-09 Commit --signoff
- G-10 Author Autocomplete — CommitView Author field with live filtering from git log history, Top 5 suggestions
- G-11 Cherry-pick range (multi-select in LogView)
- G-12 Create branch from specific commit/SHA
- G-13 Stash --keep-index
- G-14 Stash branch creation
- G-15 Log --follow renames
- G-16 Add/Remove Remote
- G-17 3-way Merge Conflict View — three-column Ours/Base/Theirs diff, per-block accept, binary detection, manual edit mode, FileMerge fallback, undo stack
- G-18 Blame previous revision with breadcrumb navigation
- G-19 Stash per-file browsing
- G-20 Submodule sync + update all
- G-21 Git config editing (local)
- G-22 Undo last commit (reset --soft HEAD~1)
- G-23 View file at specific revision
- G-24 Diff any two commits
- G-25 Git bisect with output parsing
- G-26 Git worktree management
- G-27 Git hooks management (enable/disable/edit)
- G-28 Copy Enhancement — ⌘C / right-click Copy on Stash, Tag, Branch, Submodule, Worktree lists

### Code Quality

- Unified StatusBarView across all 18 views (consistent icon + text + .bar background)
- @Sendable annotations on all Task.detached closures (94 occurrences)
- GitTaskHelper extraction — structured concurrency pattern replacing Task.detached + MainActor.run boilerplate
- BisectOutputParser extracted to Shared for testability
- CommitArgsBuilder extracted to Shared
- Stable identity for WorktreeEntry and ChangedFile (no more UUID)

### Bug Fixes

- SyncView pullRebase persistence: only persists on pull success, no longer blocks MainActor
- WorktreeView ⌘C: disabled when TextField is focused to avoid intercepting text copy
- StashView loadPatch staleness guard
- SwitchView dirty check: auto stash/pop for dirty working tree
- Config key and remote name validation (reject control characters)
- HunkParser edge cases (empty hunks, binary diffs)
- Untracked directories in Commit/Modifications view now show individual files (--untracked-files=all)

### Testing

- 163 unit tests, all passing
- Coverage: HunkParser, BisectOutputParser, ConflictParser, WorktreeView, BranchQuery, LogQuery, GitStatusParser, GitErrorMessage, SyncView logic, CommitView logic, RepoConfigQuery, ActionRouter

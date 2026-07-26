import Foundation
import AppKit

/// PanghuGit 浅 CLI：当主可执行文件以非 GUI 方式被调用时（argv 提供），在启动早期
/// 截获、处理文本命令，输出 stdout 后直接退出，避免开启任何窗口。
///
/// 使用方式（不另起可执行文件）：
///   /Applications/PanghuGit.app/Contents/MacOS/PanghuGit <command> [args...]
///
/// 通过 scripts/install_panghugit.sh 可安装 symlink：
///   ln -sf .../PanghuGit.app/Contents/MacOS/PanghuGit /usr/local/bin/panghugit
enum CLI {
    static func handleArgsIfPresent() {
        #if !DEBUG
        // 非环境变量调试时启用；argv 模式只在 argv 第一个参数以 "—" 开头或为已知
        // 动作时触发，避免误吞 Finder / URL 启动场景（后者 argv 为空或为 NSAppleEvents）。
        #endif

        let argvRaw = CommandLine.arguments
        guard argvRaw.count > 1 else { return }
        let args = Array(argvRaw.dropFirst())

        // macOS 应用二次启动时 argv 可能含 -psn_...，应忽略
        let real = args.filter { !$0.hasPrefix("-psn_") }
        guard !real.isEmpty else { return }

        // 第一个参数若是 `-Apple*` 或以 `-` 开头但不是已知 CLI flag，跳过（GUI 启动）
        let first = real[0]
        let knownFlags: Set<String> = ["--help", "-h", "--version", "-v"]
        if first.hasPrefix("-"),
           !knownFlags.contains(first),
           PanghuGitAction(rawValue: first) == nil {
            return
        }

        run(real)
        // 不返回：CLI 模式直接结束进程
        exit(0)
    }

    private static func run(_ args: [String]) {
        let cmd = args[0].lowercased()

        switch cmd {
        case "--help", "-h", "help":
            printUsage()

        case "--version", "-v", "version":
            let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            print(L10n.f("app.versionString", v))

        case "which":
            // `panghugit which <path>` 输出该路径的仓库根
            guard args.count >= 2 else { printErr(L10n.s("cli.needPath")); exit(2) }
            let url = URL(fileURLWithPath: (args[1] as NSString).standardizingPath)
            var dir = url
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == false {
                dir = url.deletingLastPathComponent()
            }
            if let root = RepoProbe.root(at: dir) {
                print(root.path)
            } else {
                printErr(L10n.f("cli.notInRepo", url.path))
                exit(1)
            }

        case "branch", "tag":
            // 文本模式：仅列出本地 + 远程分支 / tag
            guard args.count >= 2 else { printErr(L10n.s("cli.needPath")); exit(2) }
            let root = URL(fileURLWithPath: (args[1] as NSString).standardizingPath)
            if cmd == "branch" {
                for b in BranchQuery.list(root: root).values {
                    let mark = b.isHEAD ? "* " : "  "
                    print("\(mark)\(b.name)\(b.isRemote ? "  (remote)" : "")")
                }
            } else {
                for t in TagQuery.list(root: root).values {
                    print("\(t.name)\t\(t.target)\t\(t.date ?? "")")
                }
            }

        case "status-lines":
            guard args.count >= 2 else { printErr(L10n.s("cli.needPath")); exit(2) }
            let root = URL(fileURLWithPath: (args[1] as NSString).standardizingPath)
            let r = try? GitRunner.configured.run(
                ["status", "--porcelain=v1", "-z"], in: root)
            guard let r, r.isSuccess else { printErr(L10n.s("cli.statusFail")); exit(1) }
            let entries = GitStatusParser().parse(r.stdout)
            for e in entries { print("\(e.xy) \(e.path)") }

        case "log":
            runLog(args: Array(args.dropFirst()))

        case "diff":
            runDiff(args: Array(args.dropFirst()))

        case "show":
            runShow(args: Array(args.dropFirst()))

        case "open":
            // 打开对应窗口（启动 GUI + 发送 URL scheme 行进主 app）
            // 实际 CLI 用法：`panghugit open <action> <path>`
            guard args.count >= 3 else { printErr(L10n.s("cli.useOpenAction")); exit(2) }
            let actionStr = args[1]
            let target = URL(fileURLWithPath: (args[2] as NSString).standardizingPath)
            guard let action = PanghuGitAction(rawValue: actionStr) else {
                printErr(L10n.f("cli.unknownAction", actionStr))
                printActions()
                exit(2)
            }
            let url = PanghuGitURLScheme.makeURL(for: PanghuGitInvocation(
                action: action, target: target, selected: []))
            if let url, NSWorkspace.shared.open(url) {
                print("✓ open \(action.rawValue)")
                // Turbo Wait — 给 launchd 一个简短的注册窗口再退出
                usleep(100_000) // 0.1s，比原 0.2s 更短但足够稳定
            } else {
                printErr(L10n.s("cli.cannotLaunchApp"))
                exit(1)
            }

        default:
            if PanghuGitAction(rawValue: cmd) != nil {
                // 简化：`panghugit <action> <path>` 等价于 `open <action> <path>`
                run(["open", cmd] + Array(args.dropFirst()))
                return
            }
            printErr(L10n.f("cli.unknownCmd", cmd))
            printUsage()
            exit(2)
        }
    }

    // MARK: - log

    /// `panghugit log <path> [--author <name>] [--branch <ref>] [--since <date>] [-n <count>] [--oneline] [--graph]`
    private static func runLog(args: [String]) {
        guard let path = args.first(where: { !$0.hasPrefix("-") }) else {
            printErr(L10n.s("cli.logNeedPath")); exit(2)
        }
        let root = URL(fileURLWithPath: (path as NSString).standardizingPath)
        let rest = args.filter { $0 != path }
        let opts = parseLogOptions(args: rest)

        // --graph 模式：直接透传 git log --graph 的 ASCII 输出
        if opts.graph {
            var gitArgs = ["log", "--graph", "--no-color"]
            if opts.oneline { gitArgs += ["--oneline"] } else {
                gitArgs += ["--pretty=tformat:%h %ad %an %s", "--date=short"]
            }
            gitArgs += ["--max-count=\(opts.maxCount)"]
            if let b = opts.branch, !b.isEmpty { gitArgs += [b] }
            if let a = opts.author, !a.isEmpty { gitArgs += ["--author=\(a)"] }
            if let s = opts.since, !s.isEmpty { gitArgs += ["--since=\(s)"] }
            let r = try? GitRunner.configured.run(gitArgs, in: root)
            guard let r, r.isSuccess else {
                printErr(L10n.f("cli.logFail", r?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""))
                exit(1)
            }
            if !r.stdout.isEmpty {
                print(r.stdout, terminator: r.stdout.hasSuffix("\n") ? "" : "\n")
            }
            return
        }

        let entriesResult = LogQuery.entries(
            root: root,
            branch: opts.branch,
            author: opts.author,
            since: opts.since,
            maxCount: opts.maxCount
        )
        if case .failure(let msg) = entriesResult {
            printErr(L10n.f("cli.logFail", msg)); exit(1)
        }
        let entries = entriesResult.values
        if entries.isEmpty {
            if opts.oneline == false { printErr(L10n.s("cli.noCommit")); exit(1) }
            return
        }
        for e in entries {
            if opts.oneline {
                print("\(e.shortHash) \(e.subject)")
            } else {
                // 完整一行：hash<TAB>date<TAB>author<TAB>subject
                print("\(e.shortHash)\t\(e.authorDate)\t\(e.authorName)\t\(e.subject)")
            }
        }
    }

    private struct LogOptions {
        var branch: String?
        var author: String?
        var since: String?
        var maxCount: Int = 500
        var oneline: Bool = false
        var graph: Bool = false
    }

    private static func parseLogOptions(args: [String]) -> LogOptions {
        var o = LogOptions()
        var i = 0
        while i < args.count {
            let a = args[i]
            switch a {
            case "--author":
                if i + 1 < args.count { o.author = args[i + 1]; i += 2; continue }
            case "--branch":
                if i + 1 < args.count { o.branch = args[i + 1]; i += 2; continue }
            case "--since":
                if i + 1 < args.count { o.since = args[i + 1]; i += 2; continue }
            case "-n", "--max-count":
                if i + 1 < args.count, let n = Int(args[i + 1]) { o.maxCount = n; i += 2; continue }
            case "--oneline":
                o.oneline = true
            case "--graph":
                o.graph = true
            default:
                break
            }
            i += 1
        }
        return o
    }

    // MARK: - diff

    /// `panghugit diff <path> [--staged | --cached | --HEAD | -- <file> | <a> <b> [-- <file>]]`
    /// - 无 ref：工作区 vs HEAD
    /// - --staged/--cached：暂存区 vs HEAD
    /// - --HEAD：工作区 vs HEAD（显式）
    /// - <a> <b>：a..b 之间
    /// - 末尾 `-- <file>`：限定文件
    private static func runDiff(args: [String]) {
        guard let path = args.first(where: { !$0.hasPrefix("-") }) else {
            printErr(L10n.s("cli.diffNeedPath")); exit(2)
        }
        let root = URL(fileURLWithPath: (path as NSString).standardizingPath)
        let rest = args.filter { $0 != path }

        var gitArgs: [String] = ["diff", "--no-color"]
        var file: String? = nil
        var refs: [String] = []

        var i = 0
        while i < rest.count {
            let a = rest[i]
            if a == "--" {
                // 之后为文件
                if i + 1 < rest.count { file = rest[(i + 1)...].joined(separator: " ") }
                break
            } else if a == "--staged" || a == "--cached" {
                gitArgs.append("--staged")
            } else if a == "--HEAD" {
                gitArgs.append("HEAD")
            } else if a.hasPrefix("-") {
                // 透传其他 flag
                gitArgs.append(a)
            } else {
                refs.append(a)
            }
            i += 1
        }

        if refs.count == 2 {
            gitArgs.append("\(refs[0])..\(refs[1])")
        } else if refs.count == 1 {
            gitArgs.append(refs[0])
        }
        gitArgs.append("--")
        if let f = file, !f.isEmpty { gitArgs.append(f) }

        let r = try? GitRunner.configured.run(gitArgs, in: root)
        guard let r, r.isSuccess else {
            printErr(L10n.f("cli.diffFail", r?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""))
            exit(1)
        }
        // 直接输出原始 patch（适合管道）
        if !r.stdout.isEmpty {
            print(r.stdout, terminator: r.stdout.hasSuffix("\n") ? "" : "\n")
        }
    }

    // MARK: - show

    /// `panghugit show <path> <ref> [--stat | --patch]`
    /// - 默认：输出 commit 信息 + patch
    /// - --stat：仅输出改动文件清单
    private static func runShow(args: [String]) {
        guard let path = args.first(where: { !$0.hasPrefix("-") }) else {
            printErr(L10n.s("cli.showNeedPath")); exit(2)
        }
        let root = URL(fileURLWithPath: (path as NSString).standardizingPath)
        let rest = args.filter { $0 != path }
        guard let ref = rest.first(where: { !$0.hasPrefix("-") }) else {
            printErr(L10n.s("cli.showNeedRef")); exit(2)
        }
        let statOnly = rest.contains("--stat")
        var gitArgs = ["show", "--no-color"]
        if statOnly {
            gitArgs += ["--pretty=format:%H%n%an <%ae>%n%ad%n%n%s%n%n%b", "--stat"]
        } else {
            gitArgs += ["--patch"]
        }
        gitArgs.append(ref)

        let r = try? GitRunner.configured.run(gitArgs, in: root)
        guard let r, r.isSuccess else {
            printErr(L10n.f("cli.showFail", r?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""))
            exit(1)
        }
        if !r.stdout.isEmpty {
            print(r.stdout, terminator: r.stdout.hasSuffix("\n") ? "" : "\n")
        }
    }

    // MARK: - 参数解析助手

    private static func printUsage() {
        print("""
        PanghuGit CLI

        语法：
          panghugit <command> [args...]

        只读命令（输出 stdout，适合管道 / 脚本）：
          version | --version | -v        显示版本号
          which <path>                     打印该路径所在仓库根
          branch <path>                   打印分支列表（* = 当前）
          tag <path>                       打印 tag 列表
          status-lines <path>              打印 porcelain 状态行
          log <path> [--author <n>] [--branch <r>] [--since <d>] [-n <c>] [--oneline] [--graph]
                                           打印提交历史（--graph 输出 ASCII 分支图）
          diff <path> [--staged|--cached|--HEAD|<a> <b>] [-- <file>]
                                           打印 patch（工作区 vs HEAD / 暂存 vs HEAD / a..b）
          show <path> <ref> [--stat|--patch]
                                           打印某提交信息 + patch / 改动文件清单

        GUI 命令（唤起主 App 窗口）：
          open <action> <path>             打开指定窗口
          <action> <path>                  `open` 的简写

        其他：
          help | --help | -h              显示帮助

        支持的 action：
       """)
        printActions()
    }

    private static func printActions() {
        let csv = PanghuGitAction.allCases.map(\.rawValue).joined(separator: "  ")
        print("  " + csv)
    }

    private static func printErr(_ message: String) {
        FileHandle.standardError.write(Data("panghugit: \(message)\n".utf8))
    }
}
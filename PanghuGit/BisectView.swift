import SwiftUI
import AppKit

struct BisectView: View {
    let repoRoot: URL

    enum Phase { case idle, bisecting, found }

    @State private var phase: Phase = .idle
    @State private var badSHA: String = ""
    @State private var goodSHA: String = ""
    @State private var currentCommit: String = ""
    @State private var remainingSteps: Int = 0
    @State private var foundCommit: String = ""
    @State private var running = false
    @State private var status: String = ""
    @State private var error = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.s("bisect.title")).font(.headline)
                Spacer()
                if phase != .idle {
                    Button(L10n.s("bisect.reset")) { resetBisect() }
                        .buttonStyle(.bordered)
                        .disabled(running)
                }
                Button(L10n.s("common.refresh")) { }.buttonStyle(.bordered).keyboardShortcut("r", modifiers: .command)
            }

            if phase == .idle {
                idleForm
            } else {
                bisectingContent
            }

            Spacer()
        }
        .padding(16)
        .overlay(alignment: .bottom) { StatusBarView(text: status, isError: error, isLoading: running) }
        .frame(minWidth: 520, minHeight: 400)
    }

    private var idleForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L10n.s("bisect.badSHA")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                TextField("abc1234", text: $badSHA).textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 8) {
                Text(L10n.s("bisect.goodSHA")).frame(width: 80, alignment: .leading).foregroundStyle(.secondary)
                TextField("def5678", text: $goodSHA).textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button(L10n.s("bisect.start")) { startBisect() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running || badSHA.trimmingCharacters(in: .whitespaces).isEmpty || goodSHA.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    @ViewBuilder private var bisectingContent: some View {
        if phase == .found {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.s("bisect.found"))
                    .font(.title3)
                    .foregroundStyle(.green)
                Text(foundCommit).monospaced()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.f("bisect.status", remainingSteps))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !currentCommit.isEmpty {
                    Text(currentCommit).monospaced().font(.callout)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 12) {
                Button(L10n.s("bisect.markGood")) { markGood() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running)
                    .accessibilityLabel(L10n.s("bisect.markGood"))
                Button(L10n.s("bisect.markBad")) { markBad() }
                    .buttonStyle(.bordered)
                    .disabled(running)
                    .accessibilityLabel(L10n.s("bisect.markBad"))
                Button(L10n.s("bisect.skip")) { markSkip() }
                    .buttonStyle(.bordered)
                    .disabled(running)
                    .accessibilityLabel(L10n.s("bisect.skip"))
                Spacer()
            }
        }
    }

    private func startBisect() {
        let bad = badSHA.trimmingCharacters(in: .whitespaces)
        let good = goodSHA.trimmingCharacters(in: .whitespaces)
        guard !bad.isEmpty, !good.isEmpty else { return }
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let badVerify = await GitTaskHelper.runOptional(["rev-parse", "--verify", bad], in: repoRoot, timeout: 10)
            guard let badVerify, badVerify.isSuccess else {
                error = true
                status = L10n.f("bisect.invalidSHA", bad)
                running = false
                return
            }
            let goodVerify = await GitTaskHelper.runOptional(["rev-parse", "--verify", good], in: repoRoot, timeout: 10)
            guard let goodVerify, goodVerify.isSuccess else {
                error = true
                status = L10n.f("bisect.invalidSHA", good)
                running = false
                return
            }
            let startResult = await GitTaskHelper.runOptional(["bisect", "start"], in: repoRoot)
            guard let startResult, startResult.isSuccess else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(startResult?.stderr ?? ""))
                running = false
                return
            }
            let badResult = await GitTaskHelper.runOptional(["bisect", "bad", bad], in: repoRoot)
            guard let badResult, badResult.isSuccess else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(badResult?.stderr ?? ""))
                running = false
                _ = await GitTaskHelper.runOptional(["bisect", "reset"], in: repoRoot)
                return
            }
            let goodResult = await GitTaskHelper.runOptional(["bisect", "good", good], in: repoRoot)
            if let goodResult, goodResult.isSuccess {
                parseBisectOutput(goodResult.stdout)
                phase = .bisecting
                error = false
                status = ""
                running = false
            } else {
                _ = await GitTaskHelper.runOptional(["bisect", "reset"], in: repoRoot)
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(goodResult?.stderr ?? ""))
                running = false
            }
        }
    }

    private func markGood() {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(["bisect", "good"], in: repoRoot)
            if let r, r.isSuccess {
                parseBisectOutput(r.stdout)
                status = ""
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }

    private func markBad() {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(["bisect", "bad"], in: repoRoot)
            if let r, r.isSuccess {
                parseBisectOutput(r.stdout)
                status = ""
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }

    private func markSkip() {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(["bisect", "skip"], in: repoRoot)
            if let r, r.isSuccess {
                parseBisectOutput(r.stdout)
                status = ""
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }

    private func resetBisect() {
        running = true; error = false; status = L10n.s("common.running")
        Task {
            let r = await GitTaskHelper.runOptional(["bisect", "reset"], in: repoRoot)
            if let r, r.isSuccess {
                phase = .idle
                currentCommit = ""
                remainingSteps = 0
                foundCommit = ""
                error = false
                status = ""
            } else {
                error = true
                status = L10n.f("common.failed", GitErrorMessage.friendly(r?.stderr ?? ""))
            }
            running = false
        }
    }

    private func parseBisectOutput(_ output: String) {
        let result = BisectOutputParser.parse(output)
        switch result.phase {
        case .found: phase = .found
        case .bisecting: phase = .bisecting
        case .idle: phase = .idle
        }
        foundCommit = result.foundCommit
        currentCommit = result.currentCommit
        remainingSteps = result.remainingSteps
    }
}

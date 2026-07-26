import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .accessibilityLabel(L10n.s("app.name"))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.s("app.name")).font(.title.bold())
                    Text(L10n.s("app.tagline")).foregroundStyle(.secondary)
                }
            }

            Divider()

            installCheckCard

            GroupBox(L10n.s("welcome.gettingStarted")) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(L10n.s("welcome.step1"), systemImage: "1.circle")
                    Label(L10n.s("welcome.step2"), systemImage: "2.circle")
                    Label(L10n.s("welcome.step3"), systemImage: "3.circle")
                    Label(L10n.s("welcome.step4"), systemImage: "4.circle")
                }
                .font(.callout)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(L10n.s("welcome.enableFinderExt")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.s("welcome.enableHint"))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button(L10n.s("welcome.enableExtension")) {
                            BundleDiagnostics.showExtensionManagementInterface()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint(L10n.s("welcome.enableHint"))
                        Button(L10n.s("welcome.openSystemSettings")) { openSystemSettings() }
                            .accessibilityHint(L10n.s("welcome.enableHint"))
                        Button(L10n.s("welcome.restartFinder")) { BundleDiagnostics.restartFinder() }
                            .accessibilityHint(L10n.s("welcome.restartFinderHint"))
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let inv = session.lastInvocation {
                GroupBox(L10n.s("welcome.recentEvent")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(inv.action.rawValue)").monospaced()
                        Text(inv.target?.path ?? L10n.s("common.noRepo"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()
            HStack {
                Spacer()
                Text(L10n.f("app.versionSuffix", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 720, minHeight: 720)
        .padding(20)
    }

    // MARK: - 安装自检卡片

    @ViewBuilder private var installCheckCard: some View {
        if let d = session.diagnostics {
            GroupBox(L10n.s("welcome.installCheck")) {
                VStack(alignment: .leading, spacing: 8) {
                    if d.isTranslocated {
                        Label(L10n.s("welcome.translocatedWarn"), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(L10n.s("welcome.translocatedHint"))
                            .font(.caption).foregroundStyle(.secondary)
                    } else if !d.isInApplications {
                        Label(L10n.s("welcome.notInAppsWarn"), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(L10n.s("welcome.notInAppsHint"))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label(L10n.s("welcome.locationOk"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    if d.quarantineStripped {
                        Label(L10n.s("welcome.quarantineOk"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label(L10n.s("welcome.quarantineWarn"), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }

                    if d.extensionRegistered {
                        Label(L10n.s("welcome.extensionRegistered"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label(L10n.s("welcome.extensionNotRegistered"), systemImage: "questionmark.circle")
                            .foregroundStyle(.orange)
                    }

                    if !d.isTranslocated {
                        Text(L10n.s("welcome.pathLabel"))
                            .font(.caption).monospaced()
                            .foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                            .textSelection(.enabled)
                        Text(d.bundlePath)
                            .font(.caption2).monospaced()
                            .foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    Button(L10n.s("welcome.cleanupOldExtensions")) {
                        BundleDiagnostics.cleanupOldExtensions()
                        BundleDiagnostics.restartFinder()
                        session.diagnostics = BundleDiagnostics.snapshot()
                    }
                    .font(.caption)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    WelcomeView().environmentObject(MainActor.assumeIsolated { Session() })
}
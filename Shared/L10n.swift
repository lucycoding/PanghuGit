import Foundation

enum L10n {
    private static var localizationBundle: Bundle = {
        let main = Bundle.main
        if main.bundlePath.hasSuffix(".appex") {
            let appexURL = main.bundleURL
            let appURL = appexURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            if let appBundle = Bundle(url: appURL) {
                return appBundle
            }
        }
        return main
    }()

    static func s(_ key: String, comment: String = "") -> String {
        localizationBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    static func f(_ key: String, _ args: CVarArg..., comment: String = "") -> String {
        let fmt = localizationBundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: fmt, arguments: args)
    }
}
import Foundation

class PackageInfo {
    func getVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ??
            "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        if buildNumber == nil {
            return version
        }

        return "\(version)-\(buildNumber!)"
    }

    func getName() -> String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
            Bundle.main.infoDictionary?["CFBundleName"] as? String ??
            "Nebula"
    }

    func getSystemVersion() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }
}

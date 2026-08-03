import Foundation

/// Lab mock (Android labmock / desktop LAB_MOCK parity).
/// Enabled when Info.plist `LabMock` is true/1, env `NYM_VPN_APP_LAB_MOCK=1`, or compile flag `LAB_MOCK`.
public enum LabMock {
    public static let defaultAuthBaseURL = "http://104.250.122.199:8088/api/public/v1/lab/auth"
    public static let defaultProbeIP = "104.250.122.199"
    public static let labDNS = ["8.8.8.8", "1.1.1.1"]

    public static var isEnabled: Bool {
        #if LAB_MOCK
        return true
        #else
        if let flag = Bundle.main.object(forInfoDictionaryKey: "LabMock") as? Bool {
            return flag
        }
        if let flag = Bundle.main.object(forInfoDictionaryKey: "LabMock") as? String {
            let normalized = flag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "1" || normalized == "true" || normalized == "yes"
        }
        if let env = ProcessInfo.processInfo.environment["NYM_VPN_APP_LAB_MOCK"] {
            let normalized = env.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "1" || normalized == "true" || normalized == "yes"
        }
        return false
        #endif
    }

    public static var authBaseURL: String {
        if let override = ProcessInfo.processInfo.environment["NYM_VPN_APP_LAB_AUTH_BASE_URL"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "LabAuthBaseURL") as? String,
           !plist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plist.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return defaultAuthBaseURL
    }
}

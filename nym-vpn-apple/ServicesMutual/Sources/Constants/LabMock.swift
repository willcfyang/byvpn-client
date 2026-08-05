import Foundation

/// Lab mock (Android labmock / desktop LAB_MOCK parity).
/// Enabled when Info.plist `LabMock` is true/1, app-group flag, env `NYM_VPN_APP_LAB_MOCK=1`, or compile flag `LAB_MOCK`.
public enum LabMock {
    public static let defaultAuthBaseURL = "http://104.250.122.199:8088/api/public/v1/lab/auth"
    public static let defaultProbeIP = "104.250.122.199"
    public static let labDNS = ["8.8.8.8", "1.1.1.1"]
    /// Desktop `local-run/config/nym/nym-vpnd.json` entry (vpn.sf lab).
    public static let labEntryGatewayId = "3yJCWPL4X8KXNH86gYpP5LmN165Rru2jAEyxiWr9vQyP"
    /// Desktop lab exit gateway.
    public static let labExitGatewayId = "D5p6S6wiPvGYfJme5dkGvPgvcMo7Jq7FPQga3Dhhn2Vf"

    private static let appGroupLabMockKey = "byvpn.labMock.enabled"

    public static var isEnabled: Bool {
        #if LAB_MOCK
        return true
        #else
        if plistLabMockEnabled { return true }
        if appGroupLabMockEnabled { return true }
        if let env = ProcessInfo.processInfo.environment["NYM_VPN_APP_LAB_MOCK"] {
            let normalized = env.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "1" || normalized == "true" || normalized == "yes"
        }
        return false
        #endif
    }

    /// Persist so the Network Extension process can enable lab even if its Info.plist lagged.
    public static func persistAppGroupFlagIfNeeded() {
        guard plistLabMockEnabled || isEnabled else { return }
        UserDefaults(suiteName: Constants.groupID.rawValue)?.set(true, forKey: appGroupLabMockKey)
    }

    private static var plistLabMockEnabled: Bool {
        if let flag = Bundle.main.object(forInfoDictionaryKey: "LabMock") as? Bool {
            return flag
        }
        if let flag = Bundle.main.object(forInfoDictionaryKey: "LabMock") as? String {
            let normalized = flag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "1" || normalized == "true" || normalized == "yes"
        }
        return false
    }

    private static var appGroupLabMockEnabled: Bool {
        UserDefaults(suiteName: Constants.groupID.rawValue)?.bool(forKey: appGroupLabMockKey) == true
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

    /// Future own-billing API root (Alipay orders / entitlements). Nil → use `MockBillingService`.
    public static var billingBaseURL: String? {
        if let override = ProcessInfo.processInfo.environment["NYM_VPN_APP_LAB_BILLING_BASE_URL"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "LabBillingBaseURL") as? String,
           !plist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plist.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return nil
    }
}

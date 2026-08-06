import Foundation
import Constants
import Logging
import PathManager

/// Seeds vpn.sf mock discovery + lab env (Android `LabMockBootstrap` parity).
public enum LabMockBootstrap {
    private static let logger = Logger(label: "lab-mock-bootstrap")

    /// Call early in app + Network Extension so VPN core sees lab probe settings.
    public static func setLabEnvironment() {
        LabMock.persistAppGroupFlagIfNeeded()
        guard LabMock.isEnabled else { return }
        setenv("NYM_VPN_LAB_SKIP_CONNECTION_PROBE", "1", 1)
        setenv("NYM_VPN_LAB_PROBE_IP", LabMock.defaultProbeIP, 1)
        setenv("NYM_VPN_APP_LAB_MOCK", "1", 1)
        logger.info("LabMockEnv skip_probe=1 lab_mock=1 probe_ip=\(LabMock.defaultProbeIP)")
    }

    /// Writes `networks/mainnet/*.json` under the lib config cache dir (iOS).
    public static func installNetworkConfig() {
        LabMock.persistAppGroupFlagIfNeeded()
        guard LabMock.isEnabled else { return }
        do {
            let netDir = try PathManager.configFolderURL()
                .appendingPathComponent("networks", isDirectory: true)
                .appendingPathComponent("mainnet", isDirectory: true)
            try FileManager.default.createDirectory(at: netDir, withIntermediateDirectories: true)

            let discoveryURL = netDir.appendingPathComponent("mainnet_discovery.json")
            let mainnetURL = netDir.appendingPathComponent("mainnet.json")
            // Fresh updated_at so MAX_FILE_AGE does not immediately invalidate the seed.
            try stamped(LabMockNetworkAssets.discoveryJSON).write(to: discoveryURL, atomically: true, encoding: .utf8)
            try stamped(LabMockNetworkAssets.mainnetJSON).write(to: mainnetURL, atomically: true, encoding: .utf8)
            logger.info("Installed lab network config -> \(netDir.path)")
        } catch {
            logger.error("LabMockNetworkInstallFailed: \(error.localizedDescription)")
        }
    }

    public static func bootstrap() {
        setLabEnvironment()
        #if os(iOS)
        installNetworkConfig()
        #endif
    }

    private static func stamped(_ json: String) -> String {
        // Rust UtcDateTime human format: "yyyy-MM-dd HH:mm:ss.fffffffff" (no T/Z).
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSSSS"
        let now = formatter.string(from: Date())
        if json.contains("\"updated_at\"") {
            return json.replacingOccurrences(
                of: #"\"updated_at\"\s*:\s*\"[^\"]*\""#,
                with: "\"updated_at\": \"\(now)\"",
                options: .regularExpression
            )
        }
        return json
    }
}

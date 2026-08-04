import Foundation
import Constants
import Logging
import PathManager

/// Seeds vpn.sf mock discovery + lab env (Android `LabMockBootstrap` parity).
public enum LabMockBootstrap {
    private static let logger = Logger(label: "lab-mock-bootstrap")

    /// Call early in app + Network Extension so VPN core sees lab probe settings.
    public static func setLabEnvironment() {
        guard LabMock.isEnabled else { return }
        setenv("NYM_VPN_LAB_SKIP_CONNECTION_PROBE", "1", 1)
        setenv("NYM_VPN_LAB_PROBE_IP", LabMock.defaultProbeIP, 1)
        setenv("NYM_VPN_APP_LAB_MOCK", "1", 1)
        logger.info("LabMockEnv skip_probe=1 lab_mock=1 probe_ip=\(LabMock.defaultProbeIP)")
    }

    /// Writes `networks/mainnet/*.json` under the lib config cache dir (iOS).
    public static func installNetworkConfig() {
        guard LabMock.isEnabled else { return }
        do {
            let netDir = try PathManager.configFolderURL()
                .appendingPathComponent("networks", isDirectory: true)
                .appendingPathComponent("mainnet", isDirectory: true)
            try FileManager.default.createDirectory(at: netDir, withIntermediateDirectories: true)

            let discoveryURL = netDir.appendingPathComponent("mainnet_discovery.json")
            let mainnetURL = netDir.appendingPathComponent("mainnet.json")
            try LabMockNetworkAssets.discoveryJSON.write(to: discoveryURL, atomically: true, encoding: .utf8)
            try LabMockNetworkAssets.mainnetJSON.write(to: mainnetURL, atomically: true, encoding: .utf8)
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
}

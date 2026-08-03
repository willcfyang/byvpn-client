#if os(iOS)
import NetworkExtension

public enum ByVpnTunnelManager {
    private static let providerBundleID = "com.byvpn.app.tunnel"

    public static func loadManager() async throws -> NETunnelProviderManager? {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        return managers.first(
            where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                    .providerBundleIdentifier == providerBundleID
            }
        )
    }
}
#endif

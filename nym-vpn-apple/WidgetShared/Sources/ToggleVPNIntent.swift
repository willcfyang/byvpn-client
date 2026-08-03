import AppIntents
import NetworkExtension
import WidgetKit
#if os(macOS)
import AppKit
#endif

public struct ToggleVPNIntent: AppIntent {
    public static var title: LocalizedStringResource = "Toggle ByVPN"

    public init() {}

    public func perform() async throws -> some IntentResult {
#if os(iOS)
        guard let manager = try await ByVpnTunnelManager.loadManager()
        else {
            return .result()
        }

        switch manager.connection.status {
        case .connected, .connecting, .reasserting:
            manager.connection.stopVPNTunnel()
        default:
            try manager.connection.startVPNTunnel()
        }

        WidgetCenter.shared.reloadAllTimelines()
#elseif os(macOS)
        if let url = URL(string: "byvpn://vpn/toggle"),
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.byvpn.app") {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            try await NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
        }
#endif
        return .result()
    }
}

#if os(iOS)
import AppIntents
import NetworkExtension
import WidgetKit

@available(iOS 18.0, *)
public struct ToggleVPNSetValueIntent: SetValueIntent {
    public static var title: LocalizedStringResource = "Toggle ByVPN"

    @Parameter(title: "Enabled")
    public var value: Bool

    public init() {}

    public func perform() async throws -> some IntentResult {
        guard let manager = try await ByVpnTunnelManager.loadManager() else {
            return .result()
        }

        if value {
            try manager.connection.startVPNTunnel()
        } else {
            manager.connection.stopVPNTunnel()
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
#endif

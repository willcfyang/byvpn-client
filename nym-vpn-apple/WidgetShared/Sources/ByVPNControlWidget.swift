#if os(iOS)
import SwiftUI
import WidgetKit

@available(iOS 18.0, macOS 26.0, *)
public struct ByVPNControlWidget: ControlWidget {
    public static let displayName = LocalizedStringResource(stringLiteral: "ByVPN")
    public static let description = LocalizedStringResource(stringLiteral: "View and manage your VPN connection.")

    public init() {}

    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "ByVPNControlWidget",
            provider: VPNControlStatusValueProvider()
        ) { status in
            ControlWidgetToggle(
                status.isConnected ? "Connected" : "Disconnected",
                isOn: status.isConnected,
                action: ToggleVPNSetValueIntent()
            ) { isOn in
                if isOn {
                    Label("Connected", image: "byvpnConnected")
                } else {
                    Label("Disconnected", image: "byvpnDisconnected")
                }
            }
            .tint(.green)
        }
        .displayName(Self.displayName)
        .description(Self.description)
    }
}
#endif

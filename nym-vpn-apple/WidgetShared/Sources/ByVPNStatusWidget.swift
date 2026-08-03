import SwiftUI
import WidgetKit

public struct ByVPNStatusWidget: Widget {
    public let kind = "ByVPNStatusWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VPNStatusTimelineProvider()) { entry in
            VPNStatusView(entry: entry)
                .widgetURL(URL(string: "byvpn://home"))
        }
        .configurationDisplayName("ByVPN")
        .description("View and control your VPN connection.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

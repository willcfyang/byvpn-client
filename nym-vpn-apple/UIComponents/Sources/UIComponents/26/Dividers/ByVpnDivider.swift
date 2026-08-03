import SwiftUI
import Theme

public struct ByVpnDivider: View {
    private let color: Color

    public init(color: Color = .ByVpn.divider) {
        self.color = color
    }

    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: ByVpnSpacing.medium) {
        ByVpnDivider()
        ByVpnDivider(color: .ByVpn.white6)
        ByVpnDivider(color: .ByVpn.primary)
    }
    .padding(ByVpnSpacing.section)
    .background(Color.ByVpn.background)
}
#endif

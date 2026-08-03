import SwiftUI
import Theme

extension View {
    public func byVpnText(color: Color, style: ByVpnTextStyle) -> some View {
        self
            .foregroundStyle(color)
            .textStyle(style)
    }
}

import SwiftUI

public struct ByVpnTextStyleModifier: ViewModifier {
    public let textStyle: ByVpnTextStyle

    public init(textStyle: ByVpnTextStyle) {
        self.textStyle = textStyle
    }

    public func body(content: Content) -> some View {
        content
            .font(textStyle.byVpnFont.font)
            .kerning(textStyle.kerning)
            .lineSpacing(textStyle.lineSpacing)
    }
}

public extension View {
    func textStyle(_ textStyle: ByVpnTextStyle) -> some View {
        modifier(ByVpnTextStyleModifier(textStyle: textStyle))
    }
}

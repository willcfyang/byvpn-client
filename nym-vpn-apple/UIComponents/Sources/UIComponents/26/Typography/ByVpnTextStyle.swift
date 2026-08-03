import SwiftUI

public enum ByVpn {}

public extension ByVpn {
    struct TextStyle {
        public let font: Font
        public let tracking: CGFloat
        public let lineSpacing: CGFloat

        public init(font: Font, tracking: CGFloat = 0, lineSpacing: CGFloat = 0) {
            self.font = font
            self.tracking = tracking
            self.lineSpacing = lineSpacing
        }
    }
}

public extension ByVpn.TextStyle {
    static let titleScreen     = ByVpn.TextStyle(font: .ByVpn.titleScreen, tracking: -1)
    static let titleSection    = ByVpn.TextStyle(font: .ByVpn.titleSection, tracking: 1)
    static let titleSmall      = ByVpn.TextStyle(font: .ByVpn.titleSmall, tracking: 1)
    static let bodyLarge       = ByVpn.TextStyle(font: .ByVpn.bodyLarge, tracking: -0.5, lineSpacing: 4)
    static let bodyDefault     = ByVpn.TextStyle(font: .ByVpn.bodyDefault, tracking: 1, lineSpacing: 2)
    static let bodyDefaultBold = ByVpn.TextStyle(font: .ByVpn.bodyDefaultBold, tracking: 0.5)
    static let bodySmall       = ByVpn.TextStyle(font: .ByVpn.bodySmall, tracking: 1.5, lineSpacing: 2)
    static let bodySmallBold   = ByVpn.TextStyle(font: .ByVpn.bodySmallBold, tracking: 0.5)
    static let subheading      = ByVpn.TextStyle(font: .ByVpn.subheading, tracking: 2)
}

public extension View {
    func byVpnTextStyle(_ style: ByVpn.TextStyle) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}

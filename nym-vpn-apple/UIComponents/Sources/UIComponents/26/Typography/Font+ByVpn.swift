import SwiftUI

public extension Font {
    enum ByVpn {
        public static let titleScreen     = Font.system(.title3, design: .default).weight(.bold)
        public static let titleSection    = Font.system(.headline, design: .default).weight(.bold)
        public static let titleSmall      = Font.system(.subheadline, design: .default).weight(.bold)

        public static let bodyLarge       = Font.system(.body, design: .default)
        public static let bodyDefault     = Font.system(.callout, design: .default)
        public static let bodyDefaultBold = Font.system(.callout, design: .default).weight(.bold)
        public static let bodySmall       = Font.system(.caption, design: .default)
        public static let bodySmallBold   = Font.system(.caption, design: .default).weight(.bold)

        public static let subheading      = Font.system(.caption, design: .default)
    }
}

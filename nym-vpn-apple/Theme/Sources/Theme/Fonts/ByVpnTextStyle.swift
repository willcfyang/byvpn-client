import SwiftUI

public struct ByVpnTextStyle {
    public let byVpnFont: ByVpnFont
    let lineSpacing: CGFloat
    let kerning: CGFloat

    init(byVpnFont: ByVpnFont, lineSpacing: CGFloat = 0, kerning: CGFloat = 0) {
        self.byVpnFont = byVpnFont
        self.lineSpacing = lineSpacing
        self.kerning = kerning
    }

    public func withSpacing(_ lineSpacing: CGFloat) -> ByVpnTextStyle {
        ByVpnTextStyle(byVpnFont: self.byVpnFont, lineSpacing: lineSpacing, kerning: self.kerning)
    }
}

// MARK: - Styles -
extension ByVpnTextStyle {
    public struct Headline {
        public struct ExtraExtraLarge {
            public static var bold: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 48, weight: .bold), kerning: 1.2)
            }
        }

        public struct ExtraLarge {
            public static var bold: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 32, weight: .bold), kerning: 1.2)
            }
        }

        public struct Large {
            public static var regular: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 24, weight: .regular), kerning: 1.2)
            }

            public static var bold: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 24, weight: .bold), kerning: 1.2)
            }
        }

        public struct Medium {
            public static var regular: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 20, weight: .regular), kerning: 1)
            }

            public static var bold: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 20, weight: .bold), kerning: 1)
            }
        }

        public struct Small {
            public static var regular: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 16, weight: .regular), kerning: 0.8)
            }

            public static var bold: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .mono(size: 16, weight: .bold), kerning: 0.8)
            }
        }
    }

    public struct Body {
        public struct Large {
            public static var regular: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 16, weight: .regular), kerning: 0.32)
            }
        }

        public struct Medium {
            public static var regular: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 14, weight: .regular), kerning: 0.28)
            }

            public static var bold: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 14, weight: .bold), kerning: 0.28)
            }
        }

        public struct Small {
            public static var regular: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 12, weight: .regular), kerning: 0.24)
            }

            public static var bold: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .sans(size: 12, weight: .bold), kerning: 0.24)
            }
        }
    }

    public struct Body4 {
        public struct Medium {
            public static var regular: ByVpnTextStyle {
                ByVpnTextStyle(byVpnFont: .mono(size: 14, weight: .bold), kerning: 0.8)
            }
        }
    }
}

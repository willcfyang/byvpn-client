import SwiftUI

/// ByVPN typography — system fonts (store differentiation; not Lab Grotesque).
public enum ByVpnFont {
    case sans(size: CGFloat, weight: SansWeight)
    case mono(size: CGFloat, weight: MonoWeight)

    public var font: Font {
        switch self {
        case let .sans(size: size, weight: weight):
            Font.system(size: size, weight: weight.fontWeight, design: .default)
        case let .mono(size: size, weight: weight):
            Font.system(size: size, weight: weight.fontWeight, design: .monospaced)
        }
    }
}

// MARK: - Weights -

extension ByVpnFont {
    public enum SansWeight: String, CaseIterable {
        case regular
        case bold

        var fontWeight: Font.Weight {
            switch self {
            case .regular: .regular
            case .bold: .bold
            }
        }
    }

    public enum MonoWeight: String, CaseIterable {
        case regular
        case bold

        var fontWeight: Font.Weight {
            switch self {
            case .regular: .regular
            case .bold: .bold
            }
        }
    }
}

// MARK: - Register fonts -

extension ByVpnFont {
    /// No custom font files for store builds — SF system stack only.
    public static func register() {}
}

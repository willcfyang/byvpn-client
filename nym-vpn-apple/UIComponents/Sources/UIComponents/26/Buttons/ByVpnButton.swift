import SwiftUI
import Theme

public struct ByVpnButton: View {
    public enum Style {
        case primary
        case secondary
        case textOnly
        case destructive
        case connecting
        case connected

        var backgroundColor: Color {
            switch self {
            case .primary:
                .ByVpn.primary
            case .connecting:
                .ByVpn.gray1
            case .secondary,
                 .textOnly,
                 .destructive,
                 .connected:
                .clear
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary:
                .ByVpn.black
            case .connecting:
                .ByVpn.gray12
            case .secondary,
                 .textOnly:
                .ByVpn.primary
            case .connected:
                .ByVpn.textPrimary
            case .destructive:
                .ByVpn.error
            }
        }

        var borderColor: Color {
            switch self {
            case .primary, .textOnly, .connecting:
                .clear
            case .secondary:
                .ByVpn.primary
            case .destructive:
                .ByVpn.error
            case .connected:
                .ByVpn.gray2
            }
        }

        var borderWidth: CGFloat {
            switch self {
            case .primary, .textOnly, .connecting:
                0
            case .secondary, .destructive, .connected:
                1
            }
        }
    }

    private let label: String
    private let style: Style
    private let cornerRadius: CGFloat
    private let foregroundColorOverride: Color?
    private let borderColorOverride: Color?
    private let trailingSystemImage: String?
    private let action: () -> Void

    @Environment(\.isEnabled)
    private var isEnabled
    @Environment(\.accessibilityVoiceOverEnabled)
    private var voiceOverEnabled
    @State private var isHovered = false
    @State private var isDisabled: Bool

    public init(
        _ label: String,
        style: Style = .primary,
        cornerRadius: CGFloat = 8,
        foregroundColor: Color? = nil,
        borderColor: Color? = nil,
        trailingSystemImage: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.style = style
        self.cornerRadius = cornerRadius
        self.foregroundColorOverride = foregroundColor
        self.borderColorOverride = borderColor
        self.trailingSystemImage = trailingSystemImage
        self.action = action
        _isDisabled = State(initialValue: isDisabled)
    }

    public var body: some View {
        Button(action: action) {
            buttonContent
                .frame(maxWidth: .infinity)
                .frame(height: Constants.height)
                .background(effectiveBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(effectiveBorderColor, lineWidth: style.borderWidth)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
        .focusEffectDisabled(!voiceOverEnabled)
#if os(macOS)
        .focusable(voiceOverEnabled)
#endif
    }
}

private extension ByVpnButton {
    enum Constants {
        static let height: CGFloat = 45
    }

    @ViewBuilder var buttonContent: some View {
        if let trailingSystemImage {
            HStack(spacing: ByVpnSpacing.small) {
                Spacer(minLength: 0)
                Text(verbatim: label)
                    .byVpnTextStyle(.titleSmall)
                    .foregroundStyle(effectiveForeground)
                Image(systemName: trailingSystemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(effectiveForeground)
                Spacer(minLength: 0)
            }
        } else {
            Text(verbatim: label)
                .byVpnTextStyle(.titleSmall)
                .foregroundStyle(effectiveForeground)
        }
    }

    var effectiveForeground: Color {
        if !isEnabled && style == .connecting {
            return .ByVpn.gray12
        }
        return isEnabled ? (foregroundColorOverride ?? style.foregroundColor) : .ByVpn.textDisabled
    }

    var effectiveBackground: Color {
        guard isEnabled else {
            switch style {
            case .connecting:
                return .ByVpn.gray1
            case .primary:
                return .ByVpn.textDisabled.opacity(0.3)
            default:
                return .clear
            }
        }
        return isHovered ? style.backgroundColor.opacity(0.75) : style.backgroundColor
    }

    var effectiveBorderColor: Color {
        if !isEnabled && style == .connecting {
            return .clear
        }
        return isEnabled ? (borderColorOverride ?? style.borderColor) : .ByVpn.textDisabled.opacity(0.3)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: ByVpnSpacing.medium) {
        ByVpnButton("Connect", style: .primary, cornerRadius: 28) {}
        ByVpnButton("Learn more", style: .secondary) {}
        ByVpnButton("Skip", style: .textOnly) {}
        ByVpnButton("Delete account", style: .destructive) {}
        ByVpnButton("Disabled", style: .primary, isDisabled: true) {}
    }
    .padding(ByVpnSpacing.section)
    .background(Color.ByVpn.background)
}
#endif

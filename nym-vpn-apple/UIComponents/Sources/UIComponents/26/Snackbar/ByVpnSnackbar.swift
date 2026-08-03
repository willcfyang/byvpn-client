import SwiftUI
import SnackbarManager
import Theme

public struct ByVpnSnackbar: View {
    let item: SnackbarItem
    let onAction: () -> Void
    let onDismiss: () -> Void

    public init(
        item: SnackbarItem,
        onAction: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.onAction = onAction
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ByVpnSpacing.medium) {
            headerRow
            if item.actionTitle != nil {
                actionRow
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(ByVpnSpacing.large)
        .background(item.style.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 2)
    }
}

private extension ByVpnSnackbar {
    var headerRow: some View {
        HStack(alignment: .top, spacing: ByVpnSpacing.medium) {
            iconView
            VStack(alignment: .leading, spacing: ByVpnSpacing.extraExtraSmall) {
                Text(verbatim: item.title)
                    .byVpnTextStyle(.bodySmallBold)
                    .foregroundStyle(item.style.textColor)
                if let message = item.message {
                    Text(verbatim: message)
                        .byVpnTextStyle(.bodySmall)
                        .foregroundStyle(item.style.textColor.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if item.style.showsCloseButton {
                closeButton
            }
        }
    }

    var iconView: some View {
        Image(systemName: item.style.systemImageName)
            .resizable()
            .scaledToFit()
            .frame(width: Constants.Icon.size, height: Constants.Icon.size)
            .foregroundStyle(item.style.iconColor)
            .padding(.top, ByVpnSpacing.extraExtraSmall)
    }

    var actionRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            if let actionTitle = item.actionTitle {
                actionButton(title: actionTitle)
            }
        }
    }

    func actionButton(title: String) -> some View {
        SnackbarChromeButton(action: onAction) {
            Text(verbatim: title)
                .byVpnTextStyle(.bodySmallBold)
                .foregroundStyle(item.style.actionForeground)
                .padding(.horizontal, ByVpnSpacing.large)
                .padding(.vertical, ByVpnSpacing.small)
                .background(item.style.actionBackground, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(item.style.actionBorder, lineWidth: 1)
                )
        }
        .accessibilityLabel(Text(verbatim: title))
    }

    var closeButton: some View {
        SnackbarChromeButton(action: onDismiss) {
            Image(systemName: "xmark")
                .resizable()
                .scaledToFit()
                .frame(width: Constants.CloseIcon.size, height: Constants.CloseIcon.size)
                .foregroundStyle(item.style.textColor)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("close".localizedString))
    }

    enum Constants {
        static let cornerRadius: CGFloat = 12

        enum Icon {
            static let size: CGFloat = 18
        }

        enum CloseIcon {
            static let size: CGFloat = 12
        }
    }
}

private struct SnackbarChromeButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @Environment(\.accessibilityVoiceOverEnabled)
    private var voiceOverEnabled

    var body: some View {
        Button(action: action) {
            label()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled(!voiceOverEnabled)
#if os(macOS)
        .focusable(voiceOverEnabled)
#endif
    }
}

private extension SnackbarItem.Style {
    var systemImageName: String {
        switch self {
        case .critical:     "exclamationmark.circle.fill"
        case .confirmation: "checkmark.circle.fill"
        case .neutral:      "info.circle.fill"
        case .negative:     "xmark.circle.fill"
        case .warning:      "exclamationmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .critical:     .white
        case .confirmation: Color.ByVpn.success
        case .neutral:      Color.ByVpn.snackbarText
        case .negative:     Color.ByVpn.error
        case .warning:      Color.ByVpn.warning
        }
    }

    var backgroundColor: Color {
        switch self {
        case .critical: Color.ByVpn.snackbarCritical
        default:        Color.ByVpn.snackbarSurface
        }
    }

    var textColor: Color {
        switch self {
        case .critical: .white
        default:        Color.ByVpn.snackbarText
        }
    }

    var showsCloseButton: Bool {
        self != .critical
    }

    var actionBackground: Color {
        .white
    }

    var actionForeground: Color {
        Color.ByVpn.snackbarText
    }

    var actionBorder: Color {
        switch self {
        case .critical: .clear
        default:        Color.ByVpn.snackbarText.opacity(0.2)
        }
    }
}

public extension View {
    func byVpnSnackbar(manager: SnackbarManager) -> some View {
        modifier(ByVpnSnackbarManagerModifier(manager: manager))
    }
}

private struct ByVpnSnackbarManagerModifier: ViewModifier {
    let manager: SnackbarManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let item = manager.current {
                ByVpnSnackbar(
                    item: item,
                    onAction: {
                        item.onAction?()
                        manager.dismiss()
                    },
                    onDismiss: {
                        manager.dismiss()
                    }
                )
                .padding(.horizontal, Constants.horizontalInset)
                .padding(.top, Constants.topInset)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: manager.current?.id)
    }

    enum Constants {
        static let topInset: CGFloat = 92
        static let horizontalInset: CGFloat = 28
    }
}

#if DEBUG
#Preview("Critical (action)") {
    ZStack {
        Color.ByVpn.background.ignoresSafeArea()
        ByVpnSnackbar(
            item: .init(
                style: .critical,
                title: "Error connecting",
                message: "The selected gateway is not available!",
                actionTitle: "Try again",
                onAction: {}
            ),
            onAction: {},
            onDismiss: {}
        )
        .padding(.horizontal, 28)
    }
    .preferredColorScheme(.dark)
}

#Preview("Confirmation") {
    ZStack {
        Color.ByVpn.background.ignoresSafeArea()
        ByVpnSnackbar(
            item: .init(
                style: .confirmation,
                title: "Renewal success!",
                message: "Welcome back to actual privacy."
            ),
            onAction: {},
            onDismiss: {}
        )
        .padding(.horizontal, 28)
    }
    .preferredColorScheme(.dark)
}

#Preview("Warning") {
    ZStack {
        Color.ByVpn.background.ignoresSafeArea()
        ByVpnSnackbar(
            item: .init(
                style: .warning,
                title: "Subscription expired"
            ),
            onAction: {},
            onDismiss: {}
        )
        .padding(.horizontal, 28)
    }
    .preferredColorScheme(.dark)
}

#Preview("Neutral (action)") {
    ZStack {
        Color.ByVpn.background.ignoresSafeArea()
        ByVpnSnackbar(
            item: .init(
                style: .neutral,
                title: "Heads up",
                message: "Regular info",
                actionTitle: "Action",
                onAction: {}
            ),
            onAction: {},
            onDismiss: {}
        )
        .padding(.horizontal, 28)
    }
    .preferredColorScheme(.dark)
}

#Preview("Negative (action)") {
    ZStack {
        Color.ByVpn.background.ignoresSafeArea()
        ByVpnSnackbar(
            item: .init(
                style: .negative,
                title: "Negative alert",
                message: "Explain negative situation",
                actionTitle: "Action",
                onAction: {}
            ),
            onAction: {},
            onDismiss: {}
        )
        .padding(.horizontal, 28)
    }
    .preferredColorScheme(.dark)
}
#endif

import SwiftUI
import Theme
import UIComponents

public struct PassphraseSignInView: View {
    @Bindable var viewModel: PassphraseSignInViewModel
    private let minHeight: CGFloat
    private let onBackTapped: () -> Void

    @Environment(\.colorScheme)
    private var colorScheme

    public init(
        viewModel: PassphraseSignInViewModel,
        minHeight: CGFloat = 0,
        onBackTapped: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.minHeight = minHeight
        self.onBackTapped = onBackTapped
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: ByVpnSpacing.large)
            VStack(spacing: ByVpnSpacing.large) {
                heading
                textArea
                loginButton
            }
            Spacer(minLength: ByVpnSpacing.large)
        }
        .padding(.horizontal, ByVpnSpacing.component)
        .padding(.vertical, AuthLayout.verticalPadding)
        .frame(maxWidth: .infinity)
        .frame(minHeight: minHeight)
    }
}

private extension PassphraseSignInView {
    var header: some View {
        ZStack {
            GenericImage(imageName: "logoText")
                .frame(width: 100, height: 27)
            HStack {
                ByVpnBackButton(action: onBackTapped)
                Spacer()
            }
        }
    }

    var heading: some View {
        Text("passphraseSignIn.heading".localizedString)
            .byVpnTextStyle(.titleScreen)
            .foregroundStyle(Color.ByVpn.textPrimary)
            .multilineTextAlignment(.center)
    }

    var textArea: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.ByVpn.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
            ZStack(alignment: .topLeading) {
                if viewModel.passphraseText.isEmpty {
                    Text("passphraseSignIn.textArea.placeholder".localizedString)
                        .byVpnTextStyle(.bodyDefault)
                        .foregroundStyle(Color.ByVpn.textSecondary)
                        .allowsHitTesting(false)
                }
                PassphraseTextEditor(text: $viewModel.passphraseText)
            }
            .padding(ByVpnSpacing.large)
        }
        .frame(height: AuthLayout.passphraseTextAreaHeight)
    }

    @ViewBuilder
    var loginButton: some View {
        if viewModel.submissionState == .loading {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.ByVpn.gray1)
                    .frame(height: 45)
                ProgressView()
                    .tint(Color.ByVpn.gray12)
            }
        } else {
            ByVpnButton("passphraseSignIn.loginButton".localizedString, style: .primary) {
                viewModel.loginButtonTapped()
            }
        }
    }

    var borderColor: Color {
        if viewModel.submissionState == .failed {
            return Color.ByVpn.error
        }
        return colorScheme == .dark
            ? Color.ByVpn.textPrimary.opacity(0.4)
            : Color.ByVpn.textPrimary.opacity(0.3)
    }
}

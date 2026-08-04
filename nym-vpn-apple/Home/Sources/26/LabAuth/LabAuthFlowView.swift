import SwiftUI
import CredentialsManager
import ImpactGenerator
import Theme
import UIComponents

struct LabAuthFlowView: View {
    enum Step: Equatable {
        case welcome
        case register
        case login
    }

    let credentialsManager: CredentialsManager

    @State private var step: Step = .welcome
    @State private var viewModel: LabAuthViewModel

    init(credentialsManager: CredentialsManager) {
        self.credentialsManager = credentialsManager
        _viewModel = State(wrappedValue: LabAuthViewModel(credentialsManager: credentialsManager))
    }

    var body: some View {
        ZStack {
            Color.ByVpn.background.ignoresSafeArea()
            Image("byvpnGlobe", bundle: .main)
                .resizable()
                .scaledToFit()
                .opacity(0.14)
                .padding(48)
                .allowsHitTesting(false)

            Group {
                switch step {
                case .welcome:
                    welcomePanel
                        .transition(.opacity)
                case .register:
                    credentialForm(
                        title: "byvpn.auth.signup.title".localizedString,
                        submitLabel: "byvpn.auth.signup.submit".localizedString,
                        showConfirmPassword: true,
                        onBack: { step = .welcome },
                        onSubmit: {
                            viewModel.submit(mode: .register) {
                                step = .login
                            }
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                case .login:
                    credentialForm(
                        title: "byvpn.auth.login.title".localizedString,
                        submitLabel: "byvpn.auth.login.submit".localizedString,
                        showConfirmPassword: false,
                        onBack: { step = .welcome },
                        onSubmit: { viewModel.submit(mode: .login) }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: step)
            .padding(.horizontal, ByVpnSpacing.component)
        }
    }
}

private extension LabAuthFlowView {
    var welcomePanel: some View {
        VStack(spacing: ByVpnSpacing.large) {
            Spacer()
            Image("byvpnShield", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            Text("byvpn")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.ByVpn.textPrimary)
            Text("byvpn.splash.slogan".localizedString)
                .byVpnTextStyle(.titleScreen)
                .foregroundStyle(Color.ByVpn.textPrimary)
                .multilineTextAlignment(.center)
            Text("byvpn.splash.subtitle".localizedString)
                .byVpnTextStyle(.bodyDefault)
                .foregroundStyle(Color.ByVpn.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ByVpnSpacing.component)
            Spacer()
            VStack(spacing: ByVpnSpacing.component) {
                ByVpnButton("byvpn.auth.signup.submit".localizedString, style: .primary) {
                    ImpactGenerator.shared.softImpact()
                    step = .register
                }
                ByVpnButton("byvpn.auth.login.submit".localizedString, style: .secondary) {
                    ImpactGenerator.shared.softImpact()
                    step = .login
                }
            }
            .padding(.bottom, ByVpnSpacing.section)
        }
    }

    func credentialForm(
        title: String,
        submitLabel: String,
        showConfirmPassword: Bool,
        onBack: @escaping () -> Void,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(spacing: ByVpnSpacing.component) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.ByVpn.textPrimary)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Text("byvpn")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.ByVpn.primary)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.top, ByVpnSpacing.small)

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.ByVpn.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: ByVpnSpacing.component) {
                field(title: "byvpn.auth.username".localizedString, text: $viewModel.username, isSecure: false)
                field(title: "byvpn.auth.password".localizedString, text: $viewModel.password, isSecure: true)
                if showConfirmPassword {
                    field(
                        title: "byvpn.auth.confirmPassword".localizedString,
                        text: $viewModel.confirmPassword,
                        isSecure: true
                    )
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .byVpnTextStyle(.bodySmall)
                    .foregroundStyle(Color.ByVpn.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            ByVpnButton(
                viewModel.submissionState == .loading ? "…" : submitLabel,
                style: .primary,
                isDisabled: viewModel.submissionState == .loading
            ) {
                ImpactGenerator.shared.softImpact()
                onSubmit()
            }
            .padding(.bottom, ByVpnSpacing.section)
        }
    }

    func field(title: String, text: Binding<String>, isSecure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .byVpnTextStyle(.bodySmall)
                .foregroundStyle(Color.ByVpn.textSecondary)
            Group {
                if isSecure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.ByVpn.primary.opacity(0.35), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.ByVpn.backgroundCard)
                    )
            )
        }
    }
}

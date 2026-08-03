import SwiftUI
import CredentialsManager
import Constants
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
        Group {
            switch step {
            case .welcome:
                LabWelcomePanel(
                    onRegisterTapped: { step = .register },
                    onLoginTapped: { step = .login }
                )
                .transition(.slideFade(from: .leading))
            case .register:
                LabCredentialForm(
                    title: "Create lab account",
                    submitLabel: "Register",
                    showConfirmPassword: true,
                    viewModel: viewModel,
                    onBackTapped: { step = .welcome },
                    onSubmit: {
                        viewModel.submit(mode: .register) {
                            step = .login
                        }
                    }
                )
                .transition(.slideFade(from: .trailing))
            case .login:
                LabCredentialForm(
                    title: "Lab sign in",
                    submitLabel: "Sign in",
                    showConfirmPassword: false,
                    viewModel: viewModel,
                    onBackTapped: { step = .welcome },
                    onSubmit: { viewModel.submit(mode: .login) }
                )
                .transition(.slideFade(from: .trailing))
            }
        }
        .animation(.easeInOut, value: step)
        .frame(maxWidth: .infinity)
    }
}

private struct LabWelcomePanel: View {
    let onRegisterTapped: () -> Void
    let onLoginTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            GenericImage(imageName: "logoText")
                .frame(width: 100, height: 27)
            Spacer(minLength: NymSpacing.large)
            VStack(spacing: AuthLayout.stackSpacing) {
                Text("Welcome to ByVPN Lab")
                    .nymTextStyle(.titleScreen)
                    .foregroundStyle(Color.Nym.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Create a username and password for the ByVPN lab. No 24-word passphrase.")
                    .nymTextStyle(.bodyDefault)
                    .foregroundStyle(Color.Nym.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NymSpacing.component)
                VStack(spacing: NymSpacing.component) {
                    NymButton("Register", style: .primary) {
                        ImpactGenerator.shared.softImpact()
                        onRegisterTapped()
                    }
                    NymButton("Sign in", style: .primary) {
                        ImpactGenerator.shared.softImpact()
                        onLoginTapped()
                    }
                }
            }
            Spacer(minLength: NymSpacing.large)
        }
        .padding(.horizontal, NymSpacing.component)
        .padding(.vertical, AuthLayout.verticalPadding)
        .frame(maxWidth: .infinity)
    }
}

private struct LabCredentialForm: View {
    let title: String
    let submitLabel: String
    let showConfirmPassword: Bool
    @Bindable var viewModel: LabAuthViewModel
    let onBackTapped: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: AuthLayout.stackSpacing) {
            HStack {
                Button(action: onBackTapped) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.Nym.textPrimary)
                }
                Spacer()
                GenericImage(imageName: "logoText")
                    .frame(width: 80, height: 22)
                Spacer()
                Color.clear.frame(width: 24, height: 24)
            }

            Text(title)
                .nymTextStyle(.titleScreen)
                .foregroundStyle(Color.Nym.textPrimary)

            VStack(spacing: NymSpacing.component) {
                labField(title: "Username", text: $viewModel.username, isSecure: false)
                labField(title: "Password", text: $viewModel.password, isSecure: true)
                if showConfirmPassword {
                    labField(title: "Confirm password", text: $viewModel.confirmPassword, isSecure: true)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .nymTextStyle(.bodySmall)
                    .foregroundStyle(Color.Nym.error)
                    .multilineTextAlignment(.center)
            }

            NymButton(
                viewModel.submissionState == .loading ? "…" : submitLabel,
                style: .primary,
                isDisabled: viewModel.submissionState == .loading
            ) {
                ImpactGenerator.shared.softImpact()
                onSubmit()
            }
        }
        .padding(.horizontal, NymSpacing.component)
        .padding(.vertical, AuthLayout.verticalPadding)
        .frame(maxWidth: .infinity)
    }

    func labField(title: String, text: Binding<String>, isSecure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .nymTextStyle(.bodySmall)
                .foregroundStyle(Color.Nym.textSecondary)
            Group {
                if isSecure {
                    SecureField(title, text: text)
                } else {
                    TextField(title, text: text)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }
            }
            .padding(12)
            .background(Color.Nym.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(Color.Nym.textPrimary)
        }
    }
}

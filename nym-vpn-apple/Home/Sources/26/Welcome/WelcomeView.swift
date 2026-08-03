import SwiftUI
import Constants
import ImpactGenerator
import Theme
import UIComponents

public struct WelcomeView: View {
    private let minHeight: CGFloat
    private let onSignInTapped: () -> Void
    private let onSignUpTapped: () -> Void

    public init(
        minHeight: CGFloat = 0,
        onSignInTapped: @escaping () -> Void,
        onSignUpTapped: @escaping () -> Void
    ) {
        self.minHeight = minHeight
        self.onSignInTapped = onSignInTapped
        self.onSignUpTapped = onSignUpTapped
    }

    public var body: some View {
        VStack(spacing: 0) {
            logo
            Spacer(minLength: ByVpnSpacing.large)
            VStack(spacing: AuthLayout.stackSpacing) {
                heading
                subtitle
                buttons
            }
            Spacer(minLength: ByVpnSpacing.large)
            tosFooter
        }
        .padding(.horizontal, ByVpnSpacing.component)
        .padding(.vertical, AuthLayout.verticalPadding)
        .frame(maxWidth: .infinity)
        .frame(minHeight: minHeight)
    }
}

private extension WelcomeView {
    var logo: some View {
        GenericImage(imageName: "logoText")
            .frame(width: 100, height: 27)
    }

    var heading: some View {
        Text("welcome.heading".localizedString)
            .byVpnTextStyle(.titleScreen)
            .foregroundStyle(Color.ByVpn.textPrimary)
            .multilineTextAlignment(.center)
    }

    var subtitle: some View {
        Text("welcome.subtitle".localizedString)
            .byVpnTextStyle(.bodyDefault)
            .foregroundStyle(Color.ByVpn.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, ByVpnSpacing.component)
    }

    var buttons: some View {
        VStack(spacing: ByVpnSpacing.component) {
            ByVpnButton("welcome.signUp".localizedString, style: .primary) {
                ImpactGenerator.shared.softImpact()
                onSignUpTapped()
            }
            ByVpnButton("welcome.signIn".localizedString, style: .primary) {
                ImpactGenerator.shared.softImpact()
                onSignInTapped()
            }
        }
    }

    var tosFooter: some View {
        Text(tosAttributedString)
            .byVpnTextStyle(.bodySmall)
            .foregroundStyle(Color.ByVpn.textSecondary)
            .tint(Color.ByVpn.primary)
            .multilineTextAlignment(.center)
    }

    var tosAttributedString: AttributedString {
        let prefix = AttributedString("welcome.tos.prefix".localizedString)
        var terms = AttributedString("welcome.tos.terms".localizedString)
        terms.font = .ByVpn.bodySmallBold
        terms.link = URL(string: Constants.termsOfUseURL.rawValue)
        let and = AttributedString("welcome.tos.and".localizedString)
        var privacyPolicy = AttributedString("welcome.tos.privacyPolicy".localizedString)
        privacyPolicy.font = .ByVpn.bodySmallBold
        privacyPolicy.link = URL(string: Constants.privacyPolicyURL.rawValue)
        return prefix + terms + and + privacyPolicy
    }
}

#if DEBUG
#Preview {
    WelcomeView(onSignInTapped: {}, onSignUpTapped: {})
        .background(Color.ByVpn.backgroundCard)
}
#endif

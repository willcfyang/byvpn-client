import SwiftUI
import AppSettings
import Constants
import ImpactGenerator
import Theme
import UIComponents

public struct WelcomeOptInsView: View {
#if os(macOS)
    @AppStorage(AppSettingKey.statistics.rawValue)
    private var isStatisticsEnabled: Bool = true
#endif
    @AppStorage(AppSettingKey.errorReporting.rawValue)
    private var isErrorReportingOn: Bool = false

    private let onContinue: () -> Void

    public init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: ByVpnSpacing.large) {
            logo
            VStack(spacing: AuthLayout.stackSpacing) {
                heading
                subtitle
            }
            cards
            continueButton
        }
        .padding(.horizontal, ByVpnSpacing.component)
        .padding(.vertical, AuthLayout.verticalPadding)
        .frame(maxWidth: .infinity)
    }
}

private extension WelcomeOptInsView {
    var logo: some View {
        GenericImage(imageName: "logoText")
            .frame(width: 100, height: 27)
            .accessibilityHidden(true)
    }

    var heading: some View {
        Text("welcomeOptIns.title".localizedString)
            .byVpnTextStyle(.titleScreen)
            .foregroundStyle(Color.ByVpn.textPrimary)
            .multilineTextAlignment(.center)
    }

    var subtitle: some View {
        Text("welcomeOptIns.subtitle".localizedString)
            .byVpnTextStyle(.bodyDefault)
            .foregroundStyle(Color.ByVpn.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, ByVpnSpacing.component)
    }

    var cards: some View {
        VStack(spacing: ByVpnSpacing.small) {
#if os(macOS)
            optInCard(
                title: "welcomeOptIns.stats.title".localizedString,
                linkTitle: "welcomeOptIns.stats.link".localizedString,
                linkURL: URL(string: Constants.anonymousStatsURL.rawValue),
                isOn: $isStatisticsEnabled
            )
#endif
            optInCard(
                title: "welcomeOptIns.error.title".localizedString,
                linkTitle: "welcomeOptIns.error.link".localizedString,
                linkURL: URL(string: Constants.sentryURL.rawValue),
                isOn: $isErrorReportingOn
            )
        }
    }

    func optInCard(
        title: String,
        linkTitle: String,
        linkURL: URL?,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: ByVpnSpacing.small) {
                Text(title)
                    .byVpnTextStyle(.bodyDefaultBold)
                    .foregroundStyle(Color.ByVpn.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(Color.ByVpn.primary)
                    .accessibilityLabel(Text(title))
            }
            if let linkURL {
                Link(destination: linkURL) {
                    Text(linkTitle)
                        .byVpnTextStyle(.bodySmall)
                        .foregroundStyle(Color.ByVpn.info)
                        .underline()
                }
            } else {
                Text(linkTitle)
                    .byVpnTextStyle(.bodySmall)
                    .foregroundStyle(Color.ByVpn.info)
                    .underline()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.ByVpn.backgroundHover)
        )
    }

    var continueButton: some View {
        ByVpnButton("welcome.continue".localizedString, style: .primary) {
            ImpactGenerator.shared.softImpact()
            onContinue()
        }
    }
}

#if DEBUG
#Preview {
    WelcomeOptInsView(onContinue: {})
        .background(Color.ByVpn.backgroundCard)
}
#endif

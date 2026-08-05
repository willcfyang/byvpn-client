import SwiftUI
import AppSettings
import ConnectionTypes
import Constants
import CredentialsManager
import Device
import ConfigurationManager
import UIComponents
import Theme
#if os(iOS)
import Billing
#endif

public struct SettingsView: View {
    @EnvironmentObject private var credentialsManager: CredentialsManager
#if os(iOS)
    @EnvironmentObject private var billingManager: BillingManager
#endif
    @StateObject private var viewModel: SettingsViewModel
#if os(macOS)
    @State private var autologinState = AutologinState()
#endif

    public init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        SettingsFlowCoordinator(flowState: viewModel, content: content)
    }
}

private extension SettingsView {
    @ViewBuilder
    func content() -> some View {
        VStack(spacing: 0) {
            navbar()
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: ByVpnSpacing.section)
                    settingsList()
                    Spacer()
                        .frame(height: ByVpnSpacing.section)
                    appVersionText()
                        .onTapGesture(count: 3) {
                            viewModel.navigateToSantasMenu()
                        }
                }
                .padding(.horizontal, ByVpnSpacing.large)
            }
            .scrollIndicators(.never)
            .frame(maxWidth: MagicNumbers.maxWidth)
        }
        .navigationBarBackButtonHidden(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: [.bottom])
        .background {
            Color.ByVpn.background
                .ignoresSafeArea()
        }
#if os(macOS)
        .autologinOverlay(
            state: autologinState,
            onRetry: { autologinState.start(kind: .autologinRenew, using: credentialsManager) }
        )
#endif
        .onAppear {
#if os(macOS)
            viewModel.autologinState = autologinState
#endif
            Task {
                // Lab/TF: skip remote get_account (retries hang Settings for ~20s).
                if !LabMock.isEnabled {
                    await credentialsManager.updateAccountSummary()
                }
                viewModel.reloadSections()
            }
        }
    }

    @ViewBuilder
    func navbar() -> some View {
        CustomNavBar(
            title: viewModel.isTabRoot ? "byvpn".localizedString : viewModel.settingsTitle,
            backgroundColorOverride: Color.ByVpn.navBarBackground,
            leftButton: CustomNavBarButton(type: .empty, action: {}),
            rightButton: viewModel.isTabRoot
                ? CustomNavBarButton(type: .empty, action: {})
                : CustomNavBarButton(type: .close, action: { viewModel.navigateBack() })
        )
    }

    @ViewBuilder
    func settingsList() -> some View {
        VStack(spacing: ByVpnSpacing.component) {
            if viewModel.isTabRoot {
                premiumBanner
            }
            SettingsList(viewModel: SettingsListViewModel(sections: viewModel.sections))
        }
    }

    var premiumBanner: some View {
        Button {
            viewModel.navigateToPremiumPlan()
        } label: {
            HStack(spacing: ByVpnSpacing.medium) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Color.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text(premiumBannerTitle)
                        .byVpnTextStyle(.bodyDefault)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                    Text(premiumBannerSubtitle)
                        .byVpnTextStyle(.bodySmall)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(ByVpnSpacing.component)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.ByVpn.primary)
            )
        }
        .buttonStyle(.plain)
    }

#if os(iOS)
    var premiumBannerTitle: String {
        billingManager.hasActiveEntitlement
            ? "byvpn.plan.success.title".localizedString
            : "byvpn.premium.banner.title".localizedString
    }

    var premiumBannerSubtitle: String {
        if let until = billingManager.entitlementValidUntilText {
            return String(format: "byvpn.plan.success.message".localizedString, until)
        }
        return "byvpn.premium.banner.subtitle".localizedString
    }
#else
    var premiumBannerTitle: String {
        "byvpn.premium.banner.title".localizedString
    }

    var premiumBannerSubtitle: String {
        "byvpn.premium.banner.subtitle".localizedString
    }
#endif

    func appVersionText() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.versionTitle)
                    .foregroundStyle(Color.ByVpn.textSecondary)
                    .byVpnTextStyle(.bodySmall)
                    .padding(.bottom, ByVpnSpacing.large)
                Spacer()
            }
            Spacer()
                .frame(height: ByVpnSpacing.section)
        }
    }
}

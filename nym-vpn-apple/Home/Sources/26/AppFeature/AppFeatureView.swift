import SwiftUI
import AppSettings
import ConfigurationManager
import ConnectionManager
import Constants
import CredentialsManager
import ExternalLinkManager
import FeatureFlagsManager
import GatewayManager
#if os(macOS)
import GRPCManager
#endif
import ImpactGenerator
#if os(iOS)
import PurchasesManager
import Billing
#endif
import Routes
import Settings
import Theme
import UIComponents

public struct AppFeatureView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var configurationManager: ConfigurationManager
    @EnvironmentObject private var connectionManager: ConnectionManager
    @EnvironmentObject private var credentialsManager: CredentialsManager
    @EnvironmentObject private var externalLinkManager: ExternalLinkManager
    @EnvironmentObject private var featureFlagsManager: FeatureFlagsManager
    @EnvironmentObject private var gatewayManager: GatewayManager
    @EnvironmentObject private var impactGenerator: ImpactGenerator
#if os(iOS)
    @EnvironmentObject private var purchasesManager: PurchasesManager
    @EnvironmentObject private var billingManager: BillingManager
#elseif os(macOS)
    @EnvironmentObject private var grpcManager: GRPCManager
#endif

    @State private var viewModel: AppFeatureViewModel
    @AppStorage(AppSettingKey.currentAppearance.rawValue)
    private var appearance: AppSetting.Appearance = .automatic
    @AppStorage(AppSettingKey.credenitalExists.rawValue)
    private var isCredentialImported = false
    @AppStorage(AppSettingKey.welcomeScreenDidDisplay.rawValue)
    private var welcomeScreenDidDisplay = false

    @State private var selectedTab: ByVpnMainTab = .home
    @State private var homePath = NavigationPath()
    @State private var nodesPath = NavigationPath()
    @State private var settingsPath = NavigationPath()
    @State private var showNeedPlanAlert = false

    public init(viewModel: AppFeatureViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        Group {
            if !isCredentialImported {
                authGate
            } else if !welcomeScreenDidDisplay {
                optInsGate
            } else {
                mainTabs
            }
        }
        .byVpnSnackbar(manager: viewModel.snackbarManager)
        .preferredColorScheme(appearance.colorScheme)
        .onAppear {
            wireOneClickNavigation()
#if os(iOS)
            Task {
                if LabMock.isEnabled,
                   (AppSettings.shared.labUsername ?? "").isEmpty {
                    // Old sessions without per-user billing key: do not inherit shared lab-local purchase.
                    billingManager.clearLocalEntitlement()
                } else {
                    let accountId = BillingManager.accountId(
                        labUsername: AppSettings.shared.labUsername,
                        accountIdentifier: credentialsManager.accountIdentifier,
                        accountToken: credentialsManager.accountToken
                    )
                    await billingManager.refreshEntitlement(accountId: accountId)
                }
                viewModel.oneClick.refreshSubscriptionGate()
            }
#endif
        }
#if os(iOS)
        .alert(
            "byvpn.plan.needPlan.title".localizedString,
            isPresented: $showNeedPlanAlert
        ) {
            Button("byvpn.plan.needPlan.cta".localizedString) {
                openSelectPlan()
            }
            Button("cancel".localizedString, role: .cancel) {}
        } message: {
            Text("byvpn.plan.needPlan.message".localizedString)
        }
        .onChange(of: billingManager.entitlement?.orderId) { _, _ in
            viewModel.oneClick.refreshSubscriptionGate()
        }
        .onChange(of: billingManager.hasActiveEntitlement) { _, _ in
            viewModel.oneClick.refreshSubscriptionGate()
        }
#endif
        .onChange(of: isCredentialImported) { _, newValue in
            viewModel.handleCredentialChange(imported: newValue)
            wireOneClickNavigation()
            if !newValue {
#if os(iOS)
                billingManager.clearLocalEntitlement()
#endif
                selectedTab = .home
                homePath = NavigationPath()
                nodesPath = NavigationPath()
                settingsPath = NavigationPath()
            } else {
#if os(iOS)
                Task {
                    let accountId = BillingManager.accountId(
                        labUsername: AppSettings.shared.labUsername,
                        accountIdentifier: credentialsManager.accountIdentifier,
                        accountToken: credentialsManager.accountToken
                    )
                    await billingManager.refreshEntitlement(accountId: accountId)
                    viewModel.oneClick.refreshSubscriptionGate()
                }
#endif
            }
        }
    }
}

private enum ByVpnMainTab: Hashable {
    case home
    case nodes
    case settings
}

private extension AppFeatureView {
    var authGate: some View {
        ZStack {
            Color.ByVpn.background.ignoresSafeArea()
            LabAuthFlowView(credentialsManager: viewModel.credentialsManager)
        }
    }

    var optInsGate: some View {
        ZStack {
            Color.ByVpn.background.ignoresSafeArea()
            WelcomeOptInsView(
                onContinue: {
                    welcomeScreenDidDisplay = true
                    viewModel.technicalOptInsContinueTapped()
                }
            )
            .padding()
        }
    }

    var mainTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeConnectView(
                    viewModel: viewModel.oneClick,
                    onOpenNodes: { selectedTab = .nodes },
                    onOpenPremium: {
#if os(iOS)
                        openSelectPlan()
#else
                        selectedTab = .settings
                        settingsPath.append(SettingLink.selectPlan)
#endif
                    }
                )
                .navigationDestination(for: HomeLink.self) { link in
                    homeLinkDestination(link, path: $homePath)
                }
            }
            .tabItem {
                Label("byvpn.tab.home".localizedString, systemImage: "house.fill")
            }
            .tag(ByVpnMainTab.home)

            NavigationStack(path: $nodesPath) {
                GatewaysView(
                    viewModel: GatewaysViewModel(
                        type: .exit,
                        path: $nodesPath,
                        appSettings: appSettings,
                        connectionManager: connectionManager,
                        gatewayManager: gatewayManager,
                        featureFlagsManager: featureFlagsManager,
                        presentationStyle: .tabRoot
                    )
                )
                .navigationDestination(for: HomeLink.self) { link in
                    homeLinkDestination(link, path: $nodesPath)
                }
            }
            .tabItem {
                Label("byvpn.tab.nodes".localizedString, systemImage: "globe")
            }
            .tag(ByVpnMainTab.nodes)

            NavigationStack(path: $settingsPath) {
                settingsDestination(path: $settingsPath, isTabRoot: true)
            }
            .tabItem {
                Label("byvpn.tab.settings".localizedString, systemImage: "gearshape.fill")
            }
            .tag(ByVpnMainTab.settings)
        }
        .tint(Color.ByVpn.primary)
    }

    func wireOneClickNavigation() {
#if os(iOS)
        viewModel.oneClick.isSubscriptionSatisfied = { [billingManager, credentialsManager] in
            // Lab/TF: only mock/own billing unlocks connect (ignore stale VPN isActive cache).
            if LabMock.isEnabled {
                return billingManager.hasActiveEntitlement
            }
            return credentialsManager.isAccountActive() || billingManager.hasActiveEntitlement
        }
        viewModel.oneClick.onRequestPlanPurchase = {
            showNeedPlanAlert = true
        }
        viewModel.onRequestPlanPurchase = {
            showNeedPlanAlert = true
        }
        viewModel.oneClick.refreshSubscriptionGate()
#else
        viewModel.oneClick.onRequestPlanPurchase = {
            selectedTab = .settings
            settingsPath.append(SettingLink.selectPlan)
        }
        viewModel.onRequestPlanPurchase = {
            selectedTab = .settings
            settingsPath.append(SettingLink.selectPlan)
        }
#endif
#if os(macOS)
        viewModel.oneClick.onRequestDaemonEnable = {
            selectedTab = .settings
            settingsPath.append(SettingLink.daemonEnable)
        }
#endif
    }

#if os(iOS)
    func openSelectPlan() {
        selectedTab = .settings
        Task { @MainActor in
            // Wait for Settings NavigationStack to become active (tab race).
            try? await Task.sleep(for: .milliseconds(200))
            settingsPath = NavigationPath()
            try? await Task.sleep(for: .milliseconds(50))
            settingsPath.append(SettingLink.selectPlan)
        }
    }
#endif

    @ViewBuilder
    func homeLinkDestination(_ link: HomeLink, path: Binding<NavigationPath>) -> some View {
        switch link {
        case .settings:
            settingsDestination(path: path, isTabRoot: false)
        case .entryGateways:
            GatewaysView(
                viewModel: GatewaysViewModel(
                    type: .entry,
                    path: path,
                    appSettings: appSettings,
                    connectionManager: connectionManager,
                    gatewayManager: gatewayManager,
                    featureFlagsManager: featureFlagsManager
                )
            )
        case .exitGateways:
            GatewaysView(
                viewModel: GatewaysViewModel(
                    type: .exit,
                    path: path,
                    appSettings: appSettings,
                    connectionManager: connectionManager,
                    gatewayManager: gatewayManager,
                    featureFlagsManager: featureFlagsManager
                )
            )
        case let .gatewayDetails(gateway: gateway, hopType: hopType):
            ServerDetailsView(
                path: path,
                gateway: gateway,
                hopType: hopType,
                externalLinkManager: externalLinkManager
            )
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    func settingsDestination(path: Binding<NavigationPath>, isTabRoot: Bool) -> some View {
#if os(iOS)
        SettingsView(
            viewModel: SettingsViewModel(
                path: path,
                appSettings: appSettings,
                configurationManager: configurationManager,
                connectionManager: connectionManager,
                credentialsManager: credentialsManager,
                externalLinkManager: externalLinkManager,
                featureFlagsManager: featureFlagsManager,
                impactGenerator: impactGenerator,
                purchasesManager: purchasesManager,
                isTabRoot: isTabRoot
            )
        )
#elseif os(macOS)
        SettingsView(
            viewModel: SettingsViewModel(
                isServing: $grpcManager.isServing,
                path: path,
                appSettings: appSettings,
                configurationManager: configurationManager,
                connectionManager: connectionManager,
                credentialsManager: credentialsManager,
                externalLinkManager: externalLinkManager,
                featureFlagsManager: featureFlagsManager,
                impactGenerator: impactGenerator,
                isTabRoot: isTabRoot
            )
        )
#endif
    }
}

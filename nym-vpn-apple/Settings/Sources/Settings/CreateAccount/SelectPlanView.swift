#if os(iOS)
import SwiftUI
import Billing
import CredentialsManager
import ImpactGenerator
import Theme
import UIComponents

/// Figma-style Select a plan — backed by own billing (`BillingManager`), mock for demo / Alipay later.
public struct SelectPlanView: View {
    @Binding private var path: NavigationPath
    @EnvironmentObject private var billingManager: BillingManager
    @EnvironmentObject private var credentialsManager: CredentialsManager

    @State private var selectedPlanID: String?
    @State private var isPurchasing = false
    @State private var alertTitle = ""
    @State private var isAlertDisplayed = false

    public init(path: Binding<NavigationPath>) {
        _path = path
    }

    public var body: some View {
        VStack(spacing: 0) {
            CustomNavBar(
                title: "byvpn.plan.title".localizedString,
                useElevationBackground: true,
                isLogoImageHidden: true,
                leftButton: CustomNavBarButton(type: .back, action: navigateBack),
                rightButton: CustomNavBarButton(type: .empty, action: {})
            )

            ScrollView {
                VStack(alignment: .leading, spacing: ByVpnSpacing.component) {
                    Text("byvpn.plan.subtitle".localizedString)
                        .byVpnTextStyle(.bodyDefault)
                        .foregroundStyle(Color.ByVpn.textSecondary)
                        .padding(.top, ByVpnSpacing.large)

                    if billingManager.isLoadingPlans && billingManager.plans.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ByVpnSpacing.section)
                    } else if billingManager.plans.isEmpty {
                        emptyProductsCard
                    } else {
                        ForEach(billingManager.plans) { plan in
                            planCard(for: plan)
                        }
                    }

                    benefits
                    Text("byvpn.plan.mockHint".localizedString)
                        .byVpnTextStyle(.bodySmall)
                        .foregroundStyle(Color.ByVpn.textSecondary)
                        .padding(.top, ByVpnSpacing.medium)
                    Spacer(minLength: ByVpnSpacing.section)
                    ByVpnButton(
                        isPurchasing
                            ? "byvpn.plan.purchasing".localizedString
                            : "byvpn.plan.cta".localizedString,
                        style: .primary,
                        isDisabled: selectedPlan == nil || isPurchasing
                    ) {
                        purchaseSelected()
                    }
                    .disabled(selectedPlan == nil || isPurchasing)
                    .padding(.bottom, ByVpnSpacing.section)
                }
                .padding(.horizontal, ByVpnSpacing.component)
                .frame(maxWidth: MagicNumbers.moreMaxWidth)
            }
            .scrollIndicators(.never)
        }
        .navigationBarBackButtonHidden(true)
        .background { Color.ByVpn.background.ignoresSafeArea() }
        .alert(alertTitle, isPresented: $isAlertDisplayed) {
            Button("ok".localizedString, role: .cancel) {}
        }
        .task {
            await billingManager.loadPlans()
            if selectedPlanID == nil {
                selectedPlanID = preferredPlanID
            }
            if let accountId = accountIdForBilling {
                await billingManager.refreshEntitlement(accountId: accountId)
            }
        }
    }
}

private extension SelectPlanView {
    var selectedPlan: BillingPlan? {
        billingManager.plans.first { $0.id == selectedPlanID }
    }

    var preferredPlanID: String? {
        billingManager.plans.first { $0.period == .year }?.id
            ?? billingManager.plans.first?.id
    }

    var accountIdForBilling: String? {
        if let id = credentialsManager.accountIdentifier, !id.isEmpty { return id }
        if let token = credentialsManager.accountToken, !token.isEmpty { return token }
        return "lab-local"
    }

    var emptyProductsCard: some View {
        VStack(alignment: .leading, spacing: ByVpnSpacing.medium) {
            Text("byvpn.plan.unavailable.title".localizedString)
                .byVpnTextStyle(.bodyLarge)
                .foregroundStyle(Color.ByVpn.textPrimary)
            Text("byvpn.plan.unavailable.subtitle".localizedString)
                .byVpnTextStyle(.bodyDefault)
                .foregroundStyle(Color.ByVpn.textSecondary)
        }
        .padding(ByVpnSpacing.component)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.ByVpn.backgroundCard)
        )
    }

    func planCard(for plan: BillingPlan) -> some View {
        let isSelected = plan.id == selectedPlanID
        return Button {
            ImpactGenerator.shared.softImpact()
            selectedPlanID = plan.id
        } label: {
            HStack(alignment: .top, spacing: ByVpnSpacing.medium) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(periodTitle(for: plan))
                        .byVpnTextStyle(.bodyLarge)
                        .foregroundStyle(Color.ByVpn.textPrimary)
                    Text(plan.displayPrice)
                        .byVpnTextStyle(.titleScreen)
                        .foregroundStyle(Color.ByVpn.primary)
                    if let days = plan.introOfferDays, days > 0 {
                        Text("purchasePlan.7dayFreeTrial".localizedString)
                            .byVpnTextStyle(.bodySmall)
                            .foregroundStyle(Color.ByVpn.textSecondary)
                    }
                    if let description = plan.description {
                        Text(description)
                            .byVpnTextStyle(.bodySmall)
                            .foregroundStyle(Color.ByVpn.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.ByVpn.primary : Color.ByVpn.textSecondary)
            }
            .padding(ByVpnSpacing.component)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.ByVpn.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.ByVpn.primary : Color.ByVpn.gray2, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    var benefits: some View {
        VStack(alignment: .leading, spacing: ByVpnSpacing.medium) {
            benefitRow(systemName: "checkmark.seal.fill", title: "purchasePlan.allFeatures".localizedString)
            benefitRow(systemName: "nosign", title: "purchasePlan.noAds".localizedString)
            benefitRow(systemName: "arrow.uturn.backward", title: "purchasePlan.cancelAnytime".localizedString)
        }
        .padding(.top, ByVpnSpacing.large)
    }

    func benefitRow(systemName: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .foregroundStyle(Color.ByVpn.primary)
                .frame(width: 22)
            Text(title)
                .byVpnTextStyle(.bodyDefault)
                .foregroundStyle(Color.ByVpn.textSecondary)
            Spacer()
        }
    }

    func periodTitle(for plan: BillingPlan) -> String {
        switch plan.period {
        case .year:
            return "byvpn.plan.yearly".localizedString
        case .month:
            return "byvpn.plan.monthly".localizedString
        }
    }

    func navigateBack() {
        ImpactGenerator.shared.softImpact()
        if !path.isEmpty { path.removeLast() }
    }

    func purchaseSelected() {
        guard let plan = selectedPlan else { return }
        guard let accountId = accountIdForBilling else {
            alertTitle = "accountToken.empty".localizedString
            isAlertDisplayed = true
            return
        }
        isPurchasing = true
        ImpactGenerator.shared.impact()
        Task {
            defer { isPurchasing = false }
            do {
                _ = try await billingManager.purchase(planId: plan.id, accountId: accountId)
                path.append(SettingLink.processingAccount)
            } catch {
                alertTitle = error.localizedDescription
                isAlertDisplayed = true
            }
        }
    }
}
#endif

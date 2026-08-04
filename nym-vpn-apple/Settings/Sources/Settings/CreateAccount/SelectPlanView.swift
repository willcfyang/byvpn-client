#if os(iOS)
import SwiftUI
import StoreKit
import CredentialsManager
import ImpactGenerator
import PurchasesManager
import Theme
import UIComponents

/// Figma-style Select a plan screen with month / year cards.
public struct SelectPlanView: View {
    @Binding private var path: NavigationPath
    @EnvironmentObject private var purchasesManager: PurchasesManager
    @EnvironmentObject private var credentialsManager: CredentialsManager

    @State private var selectedProductID: String?
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

                    if purchasesManager.products.isEmpty {
                        emptyProductsCard
                    } else {
                        ForEach(purchasesManager.products, id: \.id) { product in
                            planCard(for: product)
                        }
                    }

                    benefits
                    Spacer(minLength: ByVpnSpacing.section)
                    ByVpnButton(
                        isPurchasing
                            ? "byvpn.plan.purchasing".localizedString
                            : "byvpn.plan.cta".localizedString,
                        style: .primary,
                        isDisabled: selectedProduct == nil || isPurchasing
                    ) {
                        purchaseSelected()
                    }
                    .disabled(selectedProduct == nil || isPurchasing)
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
            if selectedProductID == nil {
                selectedProductID = preferredProductID
            }
        }
    }
}

private extension SelectPlanView {
    var selectedProduct: Product? {
        purchasesManager.products.first { $0.id == selectedProductID }
    }

    var preferredProductID: String? {
        let yearly = purchasesManager.products.first {
            $0.subscription?.subscriptionPeriod.unit == .year
        }
        return yearly?.id ?? purchasesManager.products.first?.id
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

    func planCard(for product: Product) -> some View {
        let isSelected = product.id == selectedProductID
        return Button {
            ImpactGenerator.shared.softImpact()
            selectedProductID = product.id
        } label: {
            HStack(alignment: .top, spacing: ByVpnSpacing.medium) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(periodTitle(for: product))
                        .byVpnTextStyle(.bodyLarge)
                        .foregroundStyle(Color.ByVpn.textPrimary)
                    Text(product.displayPrice)
                        .byVpnTextStyle(.titleScreen)
                        .foregroundStyle(Color.ByVpn.primary)
                    if let offer = introOfferText(for: product) {
                        Text(offer)
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

    func periodTitle(for product: Product) -> String {
        switch product.subscription?.subscriptionPeriod.unit {
        case .year:
            return "byvpn.plan.yearly".localizedString
        case .month:
            return "byvpn.plan.monthly".localizedString
        default:
            return product.displayName
        }
    }

    func introOfferText(for product: Product) -> String? {
        guard purchasesManager.isEligibleForIntroOffer.contains(product.id),
              let offer = product.subscription?.introductoryOffer
        else { return nil }
        if offer.price == 0 {
            return "purchasePlan.7dayFreeTrial".localizedString
        }
        return "\(offer.displayPrice)"
    }

    func navigateBack() {
        ImpactGenerator.shared.softImpact()
        if !path.isEmpty { path.removeLast() }
    }

    func purchaseSelected() {
        guard let product = selectedProduct else { return }
        guard let token = credentialsManager.accountToken, !token.isEmpty else {
            alertTitle = "accountToken.empty".localizedString
            isAlertDisplayed = true
            return
        }
        isPurchasing = true
        ImpactGenerator.shared.impact()
        Task {
            defer { isPurchasing = false }
            do {
                let ok = try await purchasesManager.purchase(with: product, token: token)
                guard ok else { return }
                path.append(SettingLink.processingAccount)
            } catch {
                alertTitle = error.localizedDescription
                isAlertDisplayed = true
            }
        }
    }
}
#endif

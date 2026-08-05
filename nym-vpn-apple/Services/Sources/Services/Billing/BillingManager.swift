import Foundation
import Constants
import SwiftUI

/// App-facing billing facade. Today: mock (demo). Later: swap `service` to `RemoteBillingService` for Alipay.
@MainActor
public final class BillingManager: ObservableObject {
    public static let shared = BillingManager()

    @Published public private(set) var plans: [BillingPlan] = []
    @Published public private(set) var entitlement: BillingEntitlement?
    @Published public private(set) var isLoadingPlans = false
    @Published public private(set) var preferredChannel: PaymentChannel = .mock

    private var service: any BillingService
    private var plansLoaded = false

    public init(service: (any BillingService)? = nil) {
        self.service = service ?? Self.makeDefaultService()
        preferredChannel = LabMock.isEnabled ? .mock : .alipay
        // Lab/demo: seed Figma catalog immediately so Select Plan is never empty.
        if LabMock.isEnabled {
            plans = MockBillingService.catalog
            plansLoaded = true
        }
    }

    public var hasActiveEntitlement: Bool {
        guard let entitlement else { return false }
        return entitlement.isActive && entitlement.validUntil > Date()
    }

    public var entitlementValidUntilText: String? {
        guard hasActiveEntitlement, let entitlement else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm:ss"
        return formatter.string(from: entitlement.validUntil)
    }

    /// Swap implementation without rewriting UI (e.g. after backend ships).
    public func use(_ service: any BillingService, preferredChannel: PaymentChannel? = nil) {
        self.service = service
        plansLoaded = false
        plans = []
        if let preferredChannel {
            self.preferredChannel = preferredChannel
        }
    }

    public func loadPlans(force: Bool = false) async {
        guard force || !plansLoaded else { return }
        isLoadingPlans = true
        defer { isLoadingPlans = false }
        do {
            let fetched = try await service.fetchPlans()
            plans = fetched.isEmpty ? MockBillingService.catalog : fetched
            plansLoaded = true
        } catch {
            print("BillingManager.loadPlans: \(error)")
            plans = MockBillingService.catalog
            plansLoaded = true
        }
    }

    public func refreshEntitlement(accountId: String) async {
        let id = accountId.isEmpty ? "lab-local" : accountId
        do {
            entitlement = try await service.fetchEntitlement(accountId: id)
        } catch {
            print("BillingManager.refreshEntitlement: \(error)")
        }
    }

    /// Mock / demo purchase — never fail for known catalog plan IDs.
    public func purchase(planId: String, accountId: String) async throws -> BillingEntitlement {
        let id = accountId.isEmpty ? "lab-local" : accountId
        do {
            let result = try await service.purchase(
                planId: planId,
                accountId: id,
                channel: .mock
            )
            entitlement = result
            return result
        } catch {
            // Demo safety: grant via mock catalog so TF / Lab always succeeds.
            guard LabMock.isEnabled || preferredChannel == .mock,
                  (plans + MockBillingService.catalog).contains(where: { $0.id == planId })
            else {
                throw error
            }
            let result = try await MockBillingService.shared.purchase(
                planId: planId,
                accountId: id,
                channel: .mock
            )
            entitlement = result
            return result
        }
    }

    /// Future Alipay path: create order → hand `checkoutPayload` to Alipay SDK → confirm.
    public func createPayment(
        planId: String,
        accountId: String,
        channel: PaymentChannel,
        returnURL: String? = nil
    ) async throws -> CreatePaymentResponse {
        try await service.createPayment(
            CreatePaymentRequest(
                planId: planId,
                accountId: accountId,
                channel: channel,
                returnURL: returnURL
            )
        )
    }

    public func confirmPayment(orderId: String, accountId: String) async throws -> BillingEntitlement {
        let result = try await service.confirmPayment(orderId: orderId, accountId: accountId)
        entitlement = result
        return result
    }

    /// Resolve per-user billing id. Lab uses username so new accounts don't inherit `lab-local` purchases.
    public static func accountId(
        labUsername: String?,
        accountIdentifier: String?,
        accountToken: String?
    ) -> String {
        if let labUsername, !labUsername.isEmpty { return "lab:\(labUsername)" }
        if let accountIdentifier, !accountIdentifier.isEmpty { return accountIdentifier }
        if let accountToken, !accountToken.isEmpty { return accountToken }
        return "lab-local"
    }

    public func clearLocalEntitlement() {
        entitlement = nil
    }

    private static func makeDefaultService() -> any BillingService {
        if let remoteURL = LabMock.billingBaseURL.flatMap({ URL(string: $0) }),
           !LabMock.isEnabled {
            return RemoteBillingService(baseURL: remoteURL)
        }
        // Lab / demo: local mock with Figma plan cards.
        return MockBillingService.shared
    }
}

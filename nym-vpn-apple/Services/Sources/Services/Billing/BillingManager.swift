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
            plans = fetched
            plansLoaded = !fetched.isEmpty
        } catch {
            print("BillingManager.loadPlans: \(error)")
            // Demo safety net: always show Figma catalog if remote fails.
            plans = MockBillingService.catalog
            plansLoaded = true
        }
    }

    public func refreshEntitlement(accountId: String) async {
        guard !accountId.isEmpty else {
            entitlement = nil
            return
        }
        do {
            entitlement = try await service.fetchEntitlement(accountId: accountId)
        } catch {
            print("BillingManager.refreshEntitlement: \(error)")
        }
    }

    /// Demo purchase (create + confirm). Alipay should use `createPayment` → SDK → `confirmPayment`.
    public func purchase(planId: String, accountId: String) async throws -> BillingEntitlement {
        let result = try await service.purchase(
            planId: planId,
            accountId: accountId,
            channel: .mock
        )
        entitlement = result
        return result
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

    private static func makeDefaultService() -> any BillingService {
        if let remoteURL = LabMock.billingBaseURL.flatMap({ URL(string: $0) }),
           !LabMock.isEnabled {
            return RemoteBillingService(baseURL: remoteURL)
        }
        // Lab / demo: local mock with Figma plan cards.
        return MockBillingService.shared
    }
}

import Foundation

/// Own billing backend contract (plan C).
/// Mock implements this now; Alipay / remote HTTP will implement the same surface later.
public protocol BillingService: Sendable {
    func fetchPlans() async throws -> [BillingPlan]
    func fetchEntitlement(accountId: String) async throws -> BillingEntitlement?
    /// Start checkout. For Alipay, returns order + `checkoutPayload` for client SDK / URL.
    func createPayment(_ request: CreatePaymentRequest) async throws -> CreatePaymentResponse
    /// Poll / confirm after user finishes Alipay (or mock auto-confirm).
    func confirmPayment(orderId: String, accountId: String) async throws -> BillingEntitlement
}

public extension BillingService {
    /// Convenience: create + confirm in one step (mock / freepass). Real Alipay should call create → SDK → confirm.
    func purchase(
        planId: String,
        accountId: String,
        channel: PaymentChannel = .mock
    ) async throws -> BillingEntitlement {
        let created = try await createPayment(
            CreatePaymentRequest(planId: planId, accountId: accountId, channel: channel)
        )
        return try await confirmPayment(orderId: created.orderId, accountId: accountId)
    }
}

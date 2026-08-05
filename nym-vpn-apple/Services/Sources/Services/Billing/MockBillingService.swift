import Foundation

/// Local demo billing. Figma prices; persists entitlement in UserDefaults.
/// Replace with `RemoteBillingService` when Alipay backend is ready.
public actor MockBillingService: BillingService {
    public static let shared = MockBillingService()

    private let defaults: UserDefaults
    private let storageKeyPrefix = "byvpn.billing.mock.entitlement."
    private var pendingOrders: [String: CreatePaymentRequest] = [:]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func fetchPlans() async throws -> [BillingPlan] {
        // Slight delay so UI shows loading path in demos.
        try await Task.sleep(nanoseconds: 150_000_000)
        return Self.catalog
    }

    public func fetchEntitlement(accountId: String) async throws -> BillingEntitlement? {
        let key = storageKey(for: accountId)
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BillingEntitlement.self, from: data)
    }

    public func createPayment(_ request: CreatePaymentRequest) async throws -> CreatePaymentResponse {
        guard Self.catalog.contains(where: { $0.id == request.planId }) else {
            throw BillingError.planNotFound
        }
        let orderId = "mock-\(UUID().uuidString)"
        pendingOrders[orderId] = request
        return CreatePaymentResponse(
            orderId: orderId,
            channel: .mock,
            checkoutPayload: nil,
            expiresAt: Date().addingTimeInterval(15 * 60)
        )
    }

    public func confirmPayment(orderId: String, accountId: String) async throws -> BillingEntitlement {
        try await Task.sleep(nanoseconds: 400_000_000)
        guard let request = pendingOrders.removeValue(forKey: orderId) else {
            if let existing = try await fetchEntitlement(accountId: accountId), existing.orderId == orderId {
                return existing
            }
            throw BillingError.remote("Unknown mock order")
        }
        guard let plan = Self.catalog.first(where: { $0.id == request.planId }) else {
            throw BillingError.planNotFound
        }
        let validUntil = Self.validUntil(for: plan, from: Date())
        let entitlement = BillingEntitlement(
            accountId: accountId,
            planId: plan.id,
            isActive: true,
            validUntil: validUntil,
            channel: .mock,
            orderId: orderId
        )
        let data = try JSONEncoder().encode(entitlement)
        defaults.set(data, forKey: storageKey(for: accountId))
        return entitlement
    }

    public func clearEntitlement(accountId: String) {
        defaults.removeObject(forKey: storageKey(for: accountId))
    }

    private func storageKey(for accountId: String) -> String {
        storageKeyPrefix + accountId
    }

    public static let catalog: [BillingPlan] = [
        BillingPlan(
            id: "byvpn_month_demo",
            period: .month,
            displayName: "Monthly",
            price: Decimal(string: "12.99") ?? 12.99,
            currencyCode: "USD",
            introOfferDays: 7,
            description: "Then you'll be charged $12.99 per month. You can cancel anytime."
        ),
        BillingPlan(
            id: "byvpn_year_demo",
            period: .year,
            displayName: "Yearly",
            price: Decimal(string: "149.99") ?? 149.99,
            currencyCode: "USD",
            introOfferDays: 7,
            description: "Then you'll be charged $149.99 per year. You can cancel anytime."
        )
    ]

    private static func validUntil(for plan: BillingPlan, from start: Date) -> Date {
        var components = DateComponents()
        switch plan.period {
        case .month:
            components.month = 1
        case .year:
            components.year = 1
        }
        return Calendar.current.date(byAdding: components, to: start) ?? start.addingTimeInterval(30 * 24 * 3600)
    }
}

import Foundation

/// Billing channel. Alipay will plug in here; mock uses `.mock`.
public enum PaymentChannel: String, Codable, Sendable, CaseIterable {
    case mock
    case alipay
    case appleIAP
    case googlePlay
}

public enum BillingPeriod: String, Codable, Sendable, CaseIterable {
    case month
    case year
}

public struct BillingPlan: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let period: BillingPeriod
    public let displayName: String
    /// Major currency units (e.g. 12.99 USD).
    public let price: Decimal
    public let currencyCode: String
    public let introOfferDays: Int?
    public let description: String?

    public init(
        id: String,
        period: BillingPeriod,
        displayName: String,
        price: Decimal,
        currencyCode: String = "USD",
        introOfferDays: Int? = 7,
        description: String? = nil
    ) {
        self.id = id
        self.period = period
        self.displayName = displayName
        self.price = price
        self.currencyCode = currencyCode
        self.introOfferDays = introOfferDays
        self.description = description
    }

    public var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: price as NSDecimalNumber) ?? "\(price) \(currencyCode)"
    }
}

public struct BillingEntitlement: Codable, Sendable, Equatable {
    public let accountId: String
    public let planId: String
    public let isActive: Bool
    public let validUntil: Date
    public let channel: PaymentChannel
    public let orderId: String?

    public init(
        accountId: String,
        planId: String,
        isActive: Bool,
        validUntil: Date,
        channel: PaymentChannel,
        orderId: String? = nil
    ) {
        self.accountId = accountId
        self.planId = planId
        self.isActive = isActive
        self.validUntil = validUntil
        self.channel = channel
        self.orderId = orderId
    }
}

/// Request to open a payment (Alipay / future channels).
public struct CreatePaymentRequest: Codable, Sendable {
    public let planId: String
    public let accountId: String
    public let channel: PaymentChannel
    /// Optional return / deep-link URL after Alipay completes.
    public let returnURL: String?

    public init(planId: String, accountId: String, channel: PaymentChannel, returnURL: String? = nil) {
        self.planId = planId
        self.accountId = accountId
        self.channel = channel
        self.returnURL = returnURL
    }
}

/// Response from billing backend before user pays (order + checkout payload).
public struct CreatePaymentResponse: Codable, Sendable {
    public let orderId: String
    public let channel: PaymentChannel
    /// Alipay: payment string / URL / form HTML. Mock: empty.
    public let checkoutPayload: String?
    public let expiresAt: Date?

    public init(orderId: String, channel: PaymentChannel, checkoutPayload: String? = nil, expiresAt: Date? = nil) {
        self.orderId = orderId
        self.channel = channel
        self.checkoutPayload = checkoutPayload
        self.expiresAt = expiresAt
    }
}

public enum BillingError: Error, LocalizedError, Sendable {
    case disabled
    case planNotFound
    case paymentCancelled
    case paymentPending
    case notImplemented(String)
    case remote(String)

    public var errorDescription: String? {
        switch self {
        case .disabled:
            return "Billing is disabled"
        case .planNotFound:
            return "Plan not found"
        case .paymentCancelled:
            return "Payment cancelled"
        case .paymentPending:
            return "Payment pending"
        case let .notImplemented(what):
            return "Not implemented: \(what)"
        case let .remote(message):
            return message
        }
    }
}

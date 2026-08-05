import Foundation

/// HTTP billing client skeleton for the future Alipay-backed API.
/// Endpoints are placeholders — wire real paths when backend lands.
public actor RemoteBillingService: BillingService {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func fetchPlans() async throws -> [BillingPlan] {
        try await get(path: "plans", as: [BillingPlan].self)
    }

    public func fetchEntitlement(accountId: String) async throws -> BillingEntitlement? {
        struct Envelope: Decodable { let entitlement: BillingEntitlement? }
        let envelope: Envelope = try await get(path: "entitlements/\(accountId)", as: Envelope.self)
        return envelope.entitlement
    }

    public func createPayment(_ request: CreatePaymentRequest) async throws -> CreatePaymentResponse {
        try await post(path: "payments", body: request, as: CreatePaymentResponse.self)
    }

    public func confirmPayment(orderId: String, accountId: String) async throws -> BillingEntitlement {
        struct Body: Encodable {
            let orderId: String
            let accountId: String
        }
        return try await post(
            path: "payments/confirm",
            body: Body(orderId: orderId, accountId: accountId),
            as: BillingEntitlement.self
        )
    }

    // MARK: - HTTP

    private func get<T: Decodable>(path: String, as type: T.Type) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request, as: type)
    }

    private func post<Body: Encodable, T: Decodable>(path: String, body: Body, as type: T.Type) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request, as: type)
    }

    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BillingError.remote("Invalid response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw BillingError.remote(message)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw BillingError.remote("Decode failed: \(error.localizedDescription)")
        }
    }
}

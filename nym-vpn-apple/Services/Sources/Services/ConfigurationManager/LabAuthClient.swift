import Foundation
import Constants

/// Lab-only username/password auth against nym-mock-api (Android `LabAuthClient` parity).
public enum LabAuthClient {
    public enum LabAuthError: LocalizedError {
        case disabled
        case badRequest(String)
        case conflict(String)
        case unauthorized(String)
        case server(String)
        case invalidResponse

        public var errorDescription: String? {
            switch self {
            case .disabled:
                return "Lab auth is only available in lab mock builds"
            case .badRequest(let message),
                 .conflict(let message),
                 .unauthorized(let message),
                 .server(let message):
                return message
            case .invalidResponse:
                return "Invalid lab auth response"
            }
        }
    }

    private struct CredRequest: Encodable {
        let username: String
        let password: String
    }

    private struct LoginResponse: Decodable {
        let username: String
        let mnemonic: String
    }

    private struct ErrorResponse: Decodable {
        let error: String?
    }

    public static func register(username: String, password: String) async throws {
        guard LabMock.isEnabled else { throw LabAuthError.disabled }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !password.isEmpty else {
            throw LabAuthError.badRequest("username and password required")
        }
        guard password.count >= 8 else {
            throw LabAuthError.badRequest("Password must be at least 8 characters")
        }
        try await post(path: "register", body: CredRequest(username: trimmed, password: password), okStatus: 201)
    }

    public static func login(username: String, password: String) async throws -> String {
        guard LabMock.isEnabled else { throw LabAuthError.disabled }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !password.isEmpty else {
            throw LabAuthError.badRequest("username and password required")
        }
        let data = try await post(
            path: "login",
            body: CredRequest(username: trimmed, password: password),
            okStatus: 200
        )
        let response = try JSONDecoder().decode(LoginResponse.self, from: data)
        let mnemonic = response.mnemonic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mnemonic.isEmpty else { throw LabAuthError.invalidResponse }
        return mnemonic
    }

    @discardableResult
    private static func post(path: String, body: CredRequest, okStatus: Int) async throws -> Data {
        let base = LabMock.authBaseURL
        guard let url = URL(string: "\(base)/\(path)") else {
            throw LabAuthError.server("Invalid lab auth URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        if code == okStatus {
            return data
        }

        let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
            ?? "HTTP \(code)"
        switch code {
        case 400:
            throw LabAuthError.badRequest(message)
        case 401, 403:
            throw LabAuthError.unauthorized(message)
        case 409:
            throw LabAuthError.conflict(message)
        default:
            throw LabAuthError.server(message)
        }
    }
}

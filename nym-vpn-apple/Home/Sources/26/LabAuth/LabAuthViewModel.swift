import Foundation
import SwiftUI
import ConfigurationManager
import ConnectionManager
import Constants
import CredentialsManager
import SnackbarManager
import Theme

@MainActor
@Observable
final class LabAuthViewModel {
    enum Mode: Equatable {
        case login
        case register
    }

    enum SubmissionState: Equatable {
        case idle
        case loading
        case failed
    }

    private let credentialsManager: CredentialsManager
    private let connectionManager: ConnectionManager
    @ObservationIgnored private var task: Task<Void, Never>?

    var username: String = "" {
        didSet { clearFailure() }
    }
    var password: String = "" {
        didSet { clearFailure() }
    }
    var confirmPassword: String = "" {
        didSet { clearFailure() }
    }
    var submissionState: SubmissionState = .idle
    var errorMessage: String?

    init(
        credentialsManager: CredentialsManager,
        connectionManager: ConnectionManager = .shared
    ) {
        self.credentialsManager = credentialsManager
        self.connectionManager = connectionManager
    }

    func submit(mode: Mode, onRegistered: (() -> Void)? = nil) {
        guard submissionState != .loading else { return }
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !password.isEmpty else { return }

        if mode == .register {
            if password.count < 8 {
                fail("byvpn.auth.error.passwordTooShort".localizedString)
                return
            }
            if password != confirmPassword {
                fail("byvpn.auth.error.passwordMismatch".localizedString)
                return
            }
        }

        submissionState = .loading
        errorMessage = nil
        task?.cancel()
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                switch mode {
                case .register:
                    try await LabAuthClient.register(username: user, password: password)
                    password = ""
                    confirmPassword = ""
                    submissionState = .idle
                    SnackbarManager.shared.enqueue(
                        SnackbarItem(
                            style: .confirmation,
                            title: "byvpn.auth.registered.title".localizedString,
                            message: "byvpn.auth.registered.message".localizedString
                        )
                    )
                    onRegistered?()
                case .login:
                    let mnemonic = try await LabAuthClient.login(username: user, password: password)
                    try await credentialsManager.add(credential: mnemonic)
                    try await credentialsManager.registerAccount()
                    applyLabDNS()
                    password = ""
                    confirmPassword = ""
                    submissionState = .idle
                }
            } catch is CancellationError {
                // keep state
            } catch {
                let message = mapError(error, mode: mode)
                fail(message)
            }
        }
    }

    private func applyLabDNS() {
        connectionManager.setCustomDns(LabMock.labDNS)
        connectionManager.setCustomDnsEnabled(true)
    }

    private func mapError(_ error: Error, mode: Mode) -> String {
        if let lab = error as? LabAuthClient.LabAuthError {
            switch lab {
            case .unauthorized:
                // Lab API never distinguishes missing user vs bad password.
                return "byvpn.auth.error.invalidCredentials".localizedString
            case .conflict:
                return "byvpn.auth.error.usernameTaken".localizedString
            default:
                return lab.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private func fail(_ message: String) {
        submissionState = .failed
        errorMessage = message
        SnackbarManager.shared.enqueue(
            SnackbarItem(style: .critical, title: "error".localizedString, message: message)
        )
    }

    private func clearFailure() {
        if submissionState == .failed {
            submissionState = .idle
            errorMessage = nil
        }
    }
}

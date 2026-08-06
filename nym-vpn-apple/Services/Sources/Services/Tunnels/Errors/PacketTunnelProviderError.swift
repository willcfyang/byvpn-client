import Foundation

public enum PacketTunnelProviderError: String, Error {
    case failedToInitLogging
    case invalidSavedConfiguration
    case backendStartFailure
    case noCredentialDataDir
    case startAccountController

    /// Tunnel is cancelled because state machine entered error state.
    case errorState

    /// startTunnel waited too long without reaching connected/error.
    case startTimeout
}

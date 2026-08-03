#if os(iOS)
import ByVpnCore
#elseif os(macOS)
import ByVpnRpc
#endif

public enum GatewayBridgeParameters: Codable, Hashable {
    case quicPlain(GatewayQuicClientOptions)
}

public extension GatewayBridgeParameters {
    init(with parameters: BridgeParameters) {
        switch parameters {
        case let .quicPlain(quicClientOptions):
            self = .quicPlain(GatewayQuicClientOptions(with: quicClientOptions))
        }
    }
}

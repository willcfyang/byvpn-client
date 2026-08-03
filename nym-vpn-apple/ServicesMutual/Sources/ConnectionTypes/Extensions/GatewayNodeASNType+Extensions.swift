#if os(iOS)
import ByVpnCore
#elseif os(macOS)
import ByVpnRpc
#endif

public extension GatewayNodeASNType {
    init(with type: AsnKind) {
        switch type {
        case .residential:
            self = .residential
        case .other:
            self = .other
        }
    }
}

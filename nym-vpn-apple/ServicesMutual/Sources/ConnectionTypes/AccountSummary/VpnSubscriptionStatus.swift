#if os(iOS)
import ByVpnCore
#elseif os(macOS)
import ByVpnRpc
#endif

public enum VpnSubscriptionStatus: Equatable, Hashable, Codable {
    case pending
    case active

    public init(from status: ByVpnSubscriptionStatus) {
        switch status {
        case .pending:
            self = .pending
        case .active:
            self = .active
        }
    }
}

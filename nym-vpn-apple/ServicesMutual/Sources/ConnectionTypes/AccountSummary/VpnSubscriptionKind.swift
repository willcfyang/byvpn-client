#if os(iOS)
import ByVpnCore
#elseif os(macOS)
import ByVpnRpc
#endif

public enum VpnSubscriptionKind: Equatable, Hashable, Codable {
    case oneMonth
    case oneYear
    case twoYears
    case freepass
    case other(String)

    public init(from kind: ByVpnSubscriptionKind) {
        switch kind {
        case .oneMonth:
            self = .oneMonth
        case .oneYear:
            self = .oneYear
        case .twoYears:
            self = .twoYears
        case .freepass:
            self = .freepass
        case let .other(value):
            self = .other(value)
        }
    }
}

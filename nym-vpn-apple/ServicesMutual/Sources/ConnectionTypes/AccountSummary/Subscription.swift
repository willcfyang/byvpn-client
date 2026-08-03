#if os(iOS)
import ByVpnCore
#elseif os(macOS)
import ByVpnRpc
#endif

#if os(iOS)
public typealias OuterSubscription = ByVpnCore.Subscription
#elseif os(macOS)
public typealias OuterSubscription = ByVpnRpc.Subscription
#endif

public struct Subscription: Codable {
    public let status: VpnSubscriptionStatus
    public let subscription: VpnSubscription

    public init (status: VpnSubscriptionStatus, subscription: VpnSubscription) {
        self.status = status
        self.subscription = subscription
    }

    public init(from subscription: OuterSubscription) {
        self.status = VpnSubscriptionStatus(from: subscription.status)
        self.subscription = VpnSubscription(from: subscription.subscription)
    }
}

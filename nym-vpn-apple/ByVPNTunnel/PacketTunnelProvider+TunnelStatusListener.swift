import Foundation
import ByVpnCore

extension PacketTunnelProvider: TunnelStatusListener {
    func onEvent(event: ByVpnCore.TunnelEvent) {
        tunnelActor.onEvent(event)
    }
}

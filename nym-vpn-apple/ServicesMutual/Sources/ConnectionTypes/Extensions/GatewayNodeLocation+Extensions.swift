#if os(iOS)
import ByVpnCore
#elseif os(macOS)
import ByVpnRpc
#endif

extension GatewayNodeLocation {
    public init?(with location: Location?) {
        guard let location else { return nil }
        self.init(
            twoLetterIsoCountryCode: location.twoLetterIsoCountryCode,
            latitude: location.latitude,
            longitude: location.longitude,
            city: location.city,
            region: location.region,
            asn: GatewayNodeASN(with: location.asn)
        )
    }
}

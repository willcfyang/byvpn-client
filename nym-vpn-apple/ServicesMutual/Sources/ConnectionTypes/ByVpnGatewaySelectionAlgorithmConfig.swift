#if os(iOS)
import ByVpnCore
#elseif os(macOS)
import ByVpnRpc
#endif

public struct ByVpnGatewaySelectionAlgorithmConfig: Codable, Equatable, Sendable {
    public var enableGeoLocation: Bool
    public var algorithm: ByVpnGatewaySelectionAlgorithm

    public init(
        enableGeoLocation: Bool = true,
        algorithm: ByVpnGatewaySelectionAlgorithm = .auto
    ) {
        self.enableGeoLocation = enableGeoLocation
        self.algorithm = algorithm
    }
}

extension ByVpnGatewaySelectionAlgorithmConfig {
    public init(from sdk: GatewaySelectionAlgorithmConfig) {
        self.enableGeoLocation = sdk.enableGeoLocation
        self.algorithm = ByVpnGatewaySelectionAlgorithm(from: sdk.gatewaySelectionAlgorithm)
    }

    public var sdkValue: GatewaySelectionAlgorithmConfig {
        GatewaySelectionAlgorithmConfig(
            enableGeoLocation: enableGeoLocation,
            gatewaySelectionAlgorithm: algorithm.sdkValue
        )
    }
}

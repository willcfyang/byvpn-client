import SwiftUI
import AppSettings
import ConnectionManager
import ConnectionTypes
import FeatureFlagsManager
import GatewayManager
import ImpactGenerator
import Theme
import UIComponents

public struct GatewayCell: View {
    private let server: GatewayNode
    private let hopType: HopType
    private let isSearching: Bool

    @EnvironmentObject private var connectionManager: ConnectionManager
    @EnvironmentObject private var gatewayManager: GatewayManager
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var featureFlagsManager: FeatureFlagsManager
    @Binding private var path: NavigationPath
    @Binding private var scrollToModel: GatewayScrollToModel
    @State private var isButtonHovered = false
    @State private var isAccessoryHovered = false
    @State private var isSelected: Bool
    private var infoButtonTapCompletion: (@Sendable @MainActor (GatewayNode) -> Void)?

    private var shouldShowQuic: Bool {
        hopType == .entry
        && connectionManager.connectionType == .wireguard
        && appSettings.isQuicEnabled
    }

    private var shouldShowStreaming: Bool {
        hopType == .exit
        && server.isResidentialAvailable
    }

    public init(
        server: GatewayNode,
        type: HopType,
        path: Binding<NavigationPath>,
        scrollToModel: Binding<GatewayScrollToModel>,
        isSearching: Bool = false,
        infoButtonTapCompletion: (@Sendable @MainActor (GatewayNode) -> Void)?
    ) {
        self.server = server
        self.hopType = type
        self.isSearching = isSearching
        _path = path
        _scrollToModel = scrollToModel
        self.infoButtonTapCompletion = infoButtonTapCompletion

        let unwrappedScrollToModel = scrollToModel.wrappedValue
        let shouldSelect = unwrappedScrollToModel.serverId == server.id && unwrappedScrollToModel.isServer
        _isSelected = State(initialValue: shouldSelect)
    }

    public var body: some View {
        HStack(spacing: ByVpnSpacing.medium) {
            FlagImage(countryCode: server.location?.twoLetterIsoCountryCode, width: 28, height: 28)
                .padding(.leading, ByVpnSpacing.large)

            VStack(alignment: .leading, spacing: 4) {
                Text(server.name ?? server.id)
                    .lineLimit(1)
                    .foregroundStyle(Color.ByVpn.textPrimary)
                    .byVpnTextStyle(.bodyLarge)
                Text(serverSubtitleString())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(Color.ByVpn.textSecondary)
                    .byVpnTextStyle(.bodySmall)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { tapAction() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(server.name ?? server.id)")
            .accessibilityValue(isSelected ? "selected".localizedString : "")
            .accessibilityAddTraits([.isButton])
            .accessibilityAction { tapAction() }

            if shouldShowQuic {
                QuicLabel()
            } else if shouldShowStreaming {
                StreamingIcon()
            }

            Text(latencyLabel())
                .byVpnTextStyle(.bodySmall)
                .foregroundStyle(Color.ByVpn.textSecondary)
                .monospacedDigit()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(isSelected ? Color.ByVpn.primary : Color.ByVpn.textSecondary)
                .contentShape(Rectangle())
                .onTapGesture { tapAction() }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isAccessoryHovered ? Color.ByVpn.textPrimary : Color.ByVpn.textSecondary)
                .frame(width: 24, height: 24)
                .padding(.trailing, ByVpnSpacing.large)
                .onHover { isAccessoryHovered = $0 }
                .contentShape(Rectangle())
                .onTapGesture { infoButtonTapAction() }
                .accessibilityAction { infoButtonTapAction() }
        }
        .frame(minHeight: 64)
        .background(isButtonHovered ? Color.ByVpn.background.opacity(0.3) : Color.clear)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .inset(by: 0.5)
                .stroke(isSelected ? Color.ByVpn.primary : .clear, lineWidth: 1.5)
                .allowsHitTesting(false)
        }
        .animation(.default, value: isSelected)
        .onHover { isButtonHovered = $0 }
    }
}

private extension GatewayCell {
    func tapAction() {
        ImpactGenerator.shared.softImpact()
        switch hopType {
        case .entry:
            connectionManager.setEntryGateway(.gateway(server.id))
        case .exit:
            connectionManager.setExitGateway(.gateway(server.id))
        }
        path = .init()
    }

    func infoButtonTapAction() {
        ImpactGenerator.shared.softImpact()
        infoButtonTapCompletion?(server)
    }

    func serverSubtitleString() -> String {
        if isSearching,
           let countryCode = server.location?.twoLetterIsoCountryCode,
           let country = gatewayManager.localizedCountry(with: countryCode),
           let city = server.location?.city {
            "\(city), \(country.name)"
        } else {
            server.location?.city ?? server.id
        }
    }

    func latencyLabel() -> String {
        let score: GatewayNodeScore?
        switch connectionManager.connectionType {
        case .mixnet5hop:
            score = server.performance?.mixnetScore
        case .wireguard:
            score = server.performance?.score
        }
        guard let score else { return "— ms" }
        switch score {
        case .high:
            return "18 ms"
        case .medium:
            return "46 ms"
        case .low:
            return "92 ms"
        case .offline, .noScore:
            return "— ms"
        }
    }
}

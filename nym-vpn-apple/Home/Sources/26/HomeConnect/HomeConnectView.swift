import SwiftUI
import Theme
import UIComponents

/// Figma-aligned home connect screen (Tab root).
public struct HomeConnectView: View {
    @Bindable var viewModel: OneClickViewModel
    private let onOpenNodes: () -> Void
    private let onOpenPremium: () -> Void

    @State private var connectedAt: Date?

    public init(
        viewModel: OneClickViewModel,
        onOpenNodes: @escaping () -> Void,
        onOpenPremium: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onOpenNodes = onOpenNodes
        self.onOpenPremium = onOpenPremium
    }

    public var body: some View {
        ZStack {
            Color.ByVpn.background.ignoresSafeArea()
            dottedMapBackground
            VStack(spacing: 0) {
                header
                Spacer(minLength: ByVpnSpacing.component)
                nodeCard
                Spacer(minLength: ByVpnSpacing.large)
                durationBlock
                speedRow
                Spacer(minLength: ByVpnSpacing.large)
                connectOrb
                Text(orbStatusText)
                    .byVpnTextStyle(.bodySmall)
                    .foregroundStyle(Color.ByVpn.textSecondary)
                    .padding(.top, ByVpnSpacing.medium)
                    .opacity(orbStatusText.isEmpty ? 0 : 1)
                Spacer(minLength: ByVpnSpacing.section)
            }
            .padding(.horizontal, ByVpnSpacing.component)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.connectState) { _, newValue in
            if newValue == .connected {
                if connectedAt == nil { connectedAt = Date() }
            } else if newValue == .disconnected || newValue == .noInternet || newValue == .noSubscription {
                connectedAt = nil
            }
        }
    }
}

private extension HomeConnectView {
    var header: some View {
        HStack {
            Text("byvpn")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.ByVpn.textPrimary)
            Spacer()
            Button(action: onOpenPremium) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                    Text("Premium")
                        .byVpnTextStyle(.bodySmall)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.ByVpn.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, ByVpnSpacing.small)
    }

    var nodeCard: some View {
        Button(action: onOpenNodes) {
            HStack(spacing: ByVpnSpacing.medium) {
                flagView
                VStack(alignment: .leading, spacing: 4) {
                    Text(nodeTitle)
                        .byVpnTextStyle(.bodyDefault)
                        .foregroundStyle(Color.ByVpn.textPrimary)
                    Text(nodeSubtitle)
                        .byVpnTextStyle(.bodySmall)
                        .foregroundStyle(Color.ByVpn.textSecondary)
                }
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.ByVpn.primary)
                    Text(latencyText)
                        .byVpnTextStyle(.bodySmall)
                        .foregroundStyle(Color.ByVpn.primary)
                }
            }
            .padding(ByVpnSpacing.component)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.ByVpn.backgroundCard)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    var durationBlock: some View {
        VStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(durationString(at: context.date))
                    .font(.system(size: 44, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.ByVpn.textPrimary)
            }
            Text("byvpn.home.duration".localizedString)
                .byVpnTextStyle(.bodySmall)
                .foregroundStyle(Color.ByVpn.textSecondary)
        }
    }

    var speedRow: some View {
        HStack(spacing: ByVpnSpacing.section) {
            speedItem(icon: "arrow.down.circle.fill", title: "Download", value: "—")
            speedItem(icon: "arrow.up.circle.fill", title: "Upload", value: "—")
        }
    }

    func speedItem(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.ByVpn.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .byVpnTextStyle(.bodySmall)
                    .foregroundStyle(Color.ByVpn.textSecondary)
                Text(value)
                    .byVpnTextStyle(.bodySmall)
                    .foregroundStyle(Color.ByVpn.textPrimary)
            }
        }
    }

    var connectOrb: some View {
        Button {
            viewModel.connectButtonTapped()
        } label: {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isOrbBusy)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let wave = isOrbBusy ? (0.5 + 0.5 * sin(t * 2.6)) : 0
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        let phase = Double(index) * 0.22
                        let scale = 1.0 + wave * (0.18 + Double(index) * 0.08) + phase * wave
                        Circle()
                            .stroke(
                                Color.ByVpn.primary.opacity(isOrbBusy ? (0.55 - Double(index) * 0.14) : 0.22),
                                lineWidth: isOrbBusy ? 3 : 1.5
                            )
                            .frame(width: 168, height: 168)
                            .scaleEffect(scale)
                            .opacity(isOrbBusy ? (0.85 - Double(index) * 0.2) : 0.0)
                    }
                    Circle()
                        .fill(Color.ByVpn.primary.opacity(0.22 + wave * 0.12))
                        .frame(width: 168, height: 168)
                        .scaleEffect(isOrbBusy ? 1.0 + wave * 0.06 : 1.0)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.ByVpn.primary, Color.ByVpn.primary.opacity(0.75)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 70
                            )
                        )
                        .frame(width: 132, height: 132)
                        .shadow(color: Color.ByVpn.primary.opacity(0.45 + wave * 0.25), radius: 24 + wave * 10, y: 8)
                        .scaleEffect(isOrbBusy ? 1.0 + wave * 0.04 : 1.0)
                    Image(systemName: orbSymbol)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .symbolEffect(.pulse, isActive: isOrbBusy)
                }
                .frame(width: 220, height: 220)
            }
        }
        .buttonStyle(ConnectOrbButtonStyle())
        .accessibilityLabel(Text(orbAccessibility))
    }

    var isOrbBusy: Bool {
        switch viewModel.connectState {
        case .connecting, .disconnecting, .stop:
            true
        default:
            false
        }
    }

    var orbStatusText: String {
        switch viewModel.connectState {
        case .connecting:
            return "oneClick.connectButton.connecting".localizedString
        case .disconnecting:
            return "disconnecting".localizedString
        case .stop:
            return "stop".localizedString
        case .connected:
            return "oneClick.connectButton.connected".localizedString
        case .noSubscription:
            return "byvpn.plan.needPlan.title".localizedString
        default:
            return ""
        }
    }

    var dottedMapBackground: some View {
        Image(systemName: "globe.americas.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.ByVpn.primary.opacity(0.08))
            .padding(40)
            .allowsHitTesting(false)
    }

    var flagView: some View {
        ZStack {
            Circle()
                .fill(Color.ByVpn.primary.opacity(0.15))
                .frame(width: 44, height: 44)
            Text(countryFlagEmoji)
                .font(.system(size: 22))
        }
    }

    var nodeTitle: String {
        if case let .selected(info) = viewModel.selectionPhase {
            return info.title
        }
        return "byvpn.home.selectNode".localizedString
    }

    var nodeSubtitle: String {
        if case let .selected(info) = viewModel.selectionPhase {
            return info.subtitle ?? info.countryCode.uppercased()
        }
        return "byvpn.home.tapToSelect".localizedString
    }

    var latencyText: String {
        switch viewModel.selectionPhase.selectedInfo?.score {
        case .high: return "~50 ms"
        case .medium: return "~120 ms"
        case .low: return "~250 ms"
        default: return "—"
        }
    }

    var countryFlagEmoji: String {
        guard let code = viewModel.selectionPhase.selectedInfo?.countryCode,
              code.count == 2
        else { return "🌐" }
        let base: UInt32 = 127397
        var s = ""
        for v in code.uppercased().unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) {
                s.append(Character(scalar))
            }
        }
        return s.isEmpty ? "🌐" : s
    }

    var orbSymbol: String {
        switch viewModel.connectState {
        case .connected:
            return "bolt.fill"
        case .connecting, .disconnecting, .stop:
            return "bolt.fill"
        default:
            return "power"
        }
    }

    var orbAccessibility: String {
        switch viewModel.connectState {
        case .connected: return "Disconnect"
        case .connecting, .disconnecting, .stop: return "Cancel"
        case .noSubscription: return "Select a plan"
        default: return "Connect"
        }
    }

    func durationString(at date: Date) -> String {
        guard viewModel.connectState == .connected, let connectedAt else {
            return "00:00:00"
        }
        let elapsed = max(0, Int(date.timeIntervalSince(connectedAt)))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

private struct ConnectOrbButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

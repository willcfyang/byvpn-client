import SwiftUI
import AppSettings
import ImpactGenerator
import Theme
import UIComponents

/// Ordered word-tap verification after revealing the recovery phrase.
public struct MnemonicVerifyView: View {
    @Binding private var path: NavigationPath
    private let words: [String]
    @EnvironmentObject private var appSettings: AppSettings

    @State private var shuffled: [String] = []
    @State private var selected: [String] = []
    @State private var showError = false

    public init(path: Binding<NavigationPath>, words: [String]) {
        _path = path
        self.words = words
    }

    public var body: some View {
        VStack(spacing: 0) {
            CustomNavBar(
                title: "byvpn.mnemonic.verify.title".localizedString,
                useElevationBackground: true,
                isLogoImageHidden: true,
                leftButton: CustomNavBarButton(type: .back, action: navigateBack),
                rightButton: CustomNavBarButton(type: .empty, action: {})
            )

            ScrollView {
                VStack(alignment: .leading, spacing: ByVpnSpacing.component) {
                    Text("byvpn.mnemonic.verify.subtitle".localizedString)
                        .byVpnTextStyle(.bodyDefault)
                        .foregroundStyle(Color.ByVpn.textSecondary)
                        .padding(.top, ByVpnSpacing.large)

                    selectedStrip
                    chipGrid

                    if showError {
                        Text("byvpn.mnemonic.verify.error".localizedString)
                            .byVpnTextStyle(.bodySmall)
                            .foregroundStyle(Color.ByVpn.error)
                    }

                    Spacer(minLength: ByVpnSpacing.section)

                    ByVpnButton(
                        "byvpn.mnemonic.verify.confirm".localizedString,
                        style: .primary,
                        isDisabled: selected.count != words.count
                    ) {
                        confirm()
                    }
                    .padding(.bottom, ByVpnSpacing.section)
                }
                .padding(.horizontal, ByVpnSpacing.component)
                .frame(maxWidth: MagicNumbers.moreMaxWidth)
            }
            .scrollIndicators(.never)
        }
        .navigationBarBackButtonHidden(true)
        .background { Color.ByVpn.background.ignoresSafeArea() }
        .onAppear {
            if shuffled.isEmpty {
                shuffled = words.shuffled()
            }
        }
    }
}

private extension MnemonicVerifyView {
    var selectedStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("byvpn.mnemonic.verify.selected".localizedString)
                .byVpnTextStyle(.bodySmall)
                .foregroundStyle(Color.ByVpn.textSecondary)
            FlowLayout(spacing: 8) {
                ForEach(Array(selected.enumerated()), id: \.offset) { index, word in
                    Text("\(index + 1). \(word)")
                        .byVpnTextStyle(.bodySmall)
                        .foregroundStyle(Color.ByVpn.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.ByVpn.primary.opacity(0.15)))
                        .onTapGesture {
                            ImpactGenerator.shared.softImpact()
                            _ = selected.popLast()
                            showError = false
                        }
                }
            }
            .frame(minHeight: 44)
            .padding(ByVpnSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.ByVpn.gray2, lineWidth: 1)
            )
        }
    }

    var chipGrid: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(shuffled.enumerated()), id: \.offset) { _, word in
                let used = selected.filter { $0 == word }.count
                let total = words.filter { $0 == word }.count
                let disabled = used >= total
                Button {
                    ImpactGenerator.shared.softImpact()
                    selected.append(word)
                    showError = false
                } label: {
                    Text(word)
                        .byVpnTextStyle(.bodyDefault)
                        .foregroundStyle(disabled ? Color.ByVpn.textSecondary.opacity(0.4) : Color.ByVpn.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.ByVpn.backgroundCard)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.ByVpn.gray2, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        }
    }

    func navigateBack() {
        ImpactGenerator.shared.softImpact()
        if !path.isEmpty { path.removeLast() }
    }

    func confirm() {
        if selected == words {
            appSettings.isPassphraseStored = true
            ImpactGenerator.shared.impact()
            path = .init()
        } else {
            showError = true
            selected.removeAll()
        }
    }
}

/// Simple wrapping layout for word chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.width ?? 0, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = max(width, 1)

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), origins)
    }
}

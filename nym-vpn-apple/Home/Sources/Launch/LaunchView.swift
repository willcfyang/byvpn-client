import SwiftUI
import Theme
import UIComponents

public struct LaunchView: View {
    @Binding private var splashScreenDidDisplay: Bool
    @State private var contentOpacity: Double = 0.0

    public init(splashScreenDidDisplay: Binding<Bool>) {
        _splashScreenDidDisplay = splashScreenDidDisplay
    }

    public var body: some View {
        ZStack {
            Color.ByVpn.background.ignoresSafeArea()

            VStack(spacing: ByVpnSpacing.large) {
                Spacer()
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(Color.ByVpn.primary)
                Text("byvpn")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.ByVpn.textPrimary)
                Text("byvpn.splash.slogan".localizedString)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.ByVpn.textPrimary)
                    .multilineTextAlignment(.center)
                Text("byvpn.splash.subtitle".localizedString)
                    .byVpnTextStyle(.bodyDefault)
                    .foregroundStyle(Color.ByVpn.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ByVpnSpacing.component)
                Spacer()
            }
            .opacity(contentOpacity)
        }
        .navigationBarBackButtonHidden(true)
        .task {
            withAnimation(.easeOut(duration: 0.7)) {
                contentOpacity = 1.0
            } completion: {
                Task {
                    try? await Task.sleep(for: .seconds(0.8))
                    splashScreenDidDisplay = true
                }
            }
        }
    }
}

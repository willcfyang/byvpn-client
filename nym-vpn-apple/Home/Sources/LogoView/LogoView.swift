import SwiftUI
import Theme

public struct LogoView: View {
    public var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("byvpn")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.ByVpn.textPrimary)
                    .accessibilityLabel("byvpn")
                Spacer()
            }
            Spacer()
        }
        .background {
            Color.ByVpn.background
                .ignoresSafeArea()
        }
    }

    public init() {}
}

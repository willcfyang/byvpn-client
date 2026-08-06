import SwiftUI
import AppSettings
import Theme

public struct CustomNavBar: View {
    private let title: String?
    private let useElevationBackground: Bool
    private let isLogoImageHidden: Bool
    private let backgroundColorOverride: Color?
    @State private var leftButton: CustomNavBarButton?
    @State private var rightButton: CustomNavBarButton?

    @EnvironmentObject private var appSettings: AppSettings

    public init(
        title: String? = nil,
        useElevationBackground: Bool = false,
        isLogoImageHidden: Bool = false,
        backgroundColorOverride: Color? = nil,
        leftButton: CustomNavBarButton? = CustomNavBarButton(type: .empty, action: {}),
        rightButton: CustomNavBarButton? = CustomNavBarButton(type: .empty, action: {})
    ) {
        self.title = title
        self.useElevationBackground = useElevationBackground
        self.isLogoImageHidden = isLogoImageHidden
        self.backgroundColorOverride = backgroundColorOverride
        _leftButton = State(initialValue: leftButton)
        _rightButton = State(initialValue: rightButton)
    }

    public var body: some View {
        HStack {
            leftButton
            Spacer()
            if let title {
                Text(title)
                    .textStyle(.Headline.Medium.regular)
            } else if !isLogoImageHidden {
                Text("byvpn")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.ByVpn.textPrimary)
                    .accessibilityLabel("ByVPN".localizedString)
            }
            Spacer()
            rightButton
        }
        .frame(height: appSettings.isSmallScreen ? 48 : 64)
        .background {
            backgroundColor()
                .ignoresSafeArea()
        }
    }
}

private extension CustomNavBar {
    func backgroundColor() -> Color {
        if let backgroundColorOverride {
            return backgroundColorOverride
        }
        if useElevationBackground {
            return Color.ByVpn.background
        } else {
            return Color.ByVpn.backgroundCard
        }
    }
}

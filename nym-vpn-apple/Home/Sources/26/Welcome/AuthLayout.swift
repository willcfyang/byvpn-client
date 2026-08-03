import CoreFoundation
import UIComponents

enum AuthLayout {
    static let stackSpacing: CGFloat = {
#if os(iOS)
        ByVpnSpacing.component
#else
        ByVpnSpacing.section
#endif
    }()

    static let verticalPadding: CGFloat = ByVpnSpacing.large

    static let passphraseTextAreaHeight: CGFloat = {
#if os(iOS)
        96
#else
        127
#endif
    }()
}

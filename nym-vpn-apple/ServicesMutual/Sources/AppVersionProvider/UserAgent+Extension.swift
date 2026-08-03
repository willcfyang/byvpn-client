#if os(iOS)
import ByVpnCore

extension UserAgent {
    /// User-agent identifying the application
    public static var appUserAgent: UserAgent {
        UserAgent(
            application: AppVersionProvider.app,
            version: "\(AppVersionProvider.appVersion()) (\(AppVersionProvider.libVersion))",
            platform: AppVersionProvider.platform,
            gitCommit: ""
        )
    }
}
#endif

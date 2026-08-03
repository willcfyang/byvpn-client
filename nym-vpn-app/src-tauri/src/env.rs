use once_cell::sync::Lazy;
use std::env;

// compile-time environment variables
/// SemVer version requirement for daemon compatibility
pub const VPND_COMPAT_REQ: Option<&str> = option_env!("VPND_COMPAT_REQ");
#[cfg(windows)]
pub const UPDATER_ENDPOINT: Option<&str> = option_env!("UPDATER_ENDPOINT");

/// Default lab auth base URL (vpn.sf mock API) — matches Android labmock BuildConfig.
const DEFAULT_LAB_AUTH_BASE_URL: &str = "http://104.250.122.199:8088/api/public/v1/lab/auth";

pub static DEV_MODE: Lazy<bool> = Lazy::new(|| {
    option_env!("DEV_MODE")
        .map(|v| v == "1" || v.to_lowercase() == "true")
        .unwrap_or(false)
});
pub static UPDATER_ENABLED: Lazy<bool> = Lazy::new(|| {
    option_env!("UPDATER_ENABLED")
        .map(|v| v == "1" || v.to_lowercase() == "true")
        .unwrap_or(false)
});
/// Lab mock build: username/password auth + hide 24-word UI (Android labmock parity).
/// Compile with `LAB_MOCK=1`, or set `NYM_VPN_APP_LAB_MOCK=1` at runtime.
pub static LAB_MOCK: Lazy<bool> = Lazy::new(|| {
    if is_truthy("NYM_VPN_APP_LAB_MOCK") {
        return true;
    }
    option_env!("LAB_MOCK")
        .map(|v| v == "1" || v.to_lowercase() == "true")
        .unwrap_or(false)
});
pub static LAB_AUTH_BASE_URL: Lazy<String> = Lazy::new(|| {
    env::var("NYM_VPN_APP_LAB_AUTH_BASE_URL")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .or_else(|| option_env!("LAB_AUTH_BASE_URL").map(|s| s.to_string()))
        .unwrap_or_else(|| DEFAULT_LAB_AUTH_BASE_URL.to_string())
        .trim_end_matches('/')
        .to_string()
});
pub static APP_SENTRY_DSN: Lazy<Option<String>> = Lazy::new(|| {
    env::var("APP_SENTRY_DSN")
        .ok()
        .or_else(|| option_env!("APP_SENTRY_DSN").map(|s| s.to_string()))
});

/// Check if an environment variable is truthy, e.g. set to "1" | "true" | "TRUE"
pub fn is_truthy(var: &str) -> bool {
    match env::var(var) {
        Ok(val) => val == "1" || val.to_lowercase() == "true",
        Err(_) => false,
    }
}

//! Lab-only username/password auth against nym-mock-api (Android labmock parity).
//! Runs in Rust because CSP blocks cleartext HTTP from the webview.

use serde::Deserialize;
use tracing::{error, info, instrument};

use crate::env::{LAB_AUTH_BASE_URL, LAB_MOCK};
use crate::error::{BackendError, ErrorKey};

#[derive(serde::Serialize)]
struct CredRequest<'a> {
    username: &'a str,
    password: &'a str,
}

#[derive(Deserialize)]
struct LoginResponse {
    #[allow(dead_code)]
    username: String,
    mnemonic: String,
}

#[derive(Deserialize)]
struct ErrorResponse {
    error: Option<String>,
}

fn require_lab_mock() -> Result<(), BackendError> {
    if *LAB_MOCK {
        Ok(())
    } else {
        Err(BackendError::new(
            "lab auth is only available in LAB_MOCK builds",
            ErrorKey::Internal,
        ))
    }
}

fn map_http_error(code: u16, body: &str) -> BackendError {
    let err = serde_json::from_str::<ErrorResponse>(body)
        .ok()
        .and_then(|e| e.error)
        .unwrap_or_else(|| format!("HTTP {code}"));
    let key = match code {
        400 => ErrorKey::Internal,
        401 | 403 => ErrorKey::Internal,
        409 => ErrorKey::Internal,
        _ => ErrorKey::Internal,
    };
    BackendError::with_detail(&format!("lab auth failed: {err}"), key, err)
}

#[instrument(skip(password))]
#[tauri::command]
pub async fn lab_auth_register(username: String, password: String) -> Result<(), BackendError> {
    require_lab_mock()?;
    let username = username.trim();
    if username.is_empty() || password.is_empty() {
        return Err(BackendError::internal("username and password required", None));
    }
    if password.len() < 8 {
        return Err(BackendError::internal_with_detail(
            "password too short",
            "Password must be at least 8 characters".into(),
        ));
    }

    let url = format!("{}/register", *LAB_AUTH_BASE_URL);
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(15))
        .build()
        .map_err(|e| BackendError::internal(&format!("http client: {e}"), None))?;

    let resp = client
        .post(&url)
        .header("Content-Type", "application/json; charset=utf-8")
        .json(&CredRequest {
            username,
            password: &password,
        })
        .send()
        .await
        .map_err(|e| {
            error!("lab register request failed: {e}");
            BackendError::internal_with_detail("lab register request failed", e.to_string())
        })?;

    let status = resp.status();
    let body = resp.text().await.unwrap_or_default();
    if status.as_u16() == 201 {
        info!("lab account registered: {username}");
        return Ok(());
    }
    Err(map_http_error(status.as_u16(), &body))
}

#[instrument(skip(password))]
#[tauri::command]
pub async fn lab_auth_login(username: String, password: String) -> Result<String, BackendError> {
    require_lab_mock()?;
    let username = username.trim();
    if username.is_empty() || password.is_empty() {
        return Err(BackendError::internal("username and password required", None));
    }

    let url = format!("{}/login", *LAB_AUTH_BASE_URL);
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(15))
        .build()
        .map_err(|e| BackendError::internal(&format!("http client: {e}"), None))?;

    let resp = client
        .post(&url)
        .header("Content-Type", "application/json; charset=utf-8")
        .json(&CredRequest {
            username,
            password: &password,
        })
        .send()
        .await
        .map_err(|e| {
            error!("lab login request failed: {e}");
            BackendError::internal_with_detail("lab login request failed", e.to_string())
        })?;

    let status = resp.status();
    let body = resp.text().await.unwrap_or_default();
    if status.as_u16() != 200 {
        return Err(map_http_error(status.as_u16(), &body));
    }

    let parsed: LoginResponse = serde_json::from_str(&body).map_err(|e| {
        BackendError::internal_with_detail("invalid lab login response", e.to_string())
    })?;
    if parsed.mnemonic.trim().is_empty() {
        return Err(BackendError::internal("lab login returned empty mnemonic", None));
    }
    info!("lab login ok: {username}");
    Ok(parsed.mnemonic)
}

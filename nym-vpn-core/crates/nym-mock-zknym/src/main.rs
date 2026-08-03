use std::{net::SocketAddr, sync::Arc};

use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    routing::{get, post},
};
use nym_credential_proxy_requests::api::v1::ticketbook::models::PartialVerificationKeysResponse;
use nym_vpn_api_client::{
    request::RequestZkNymRequestBody,
    response::NymVpnZkNymResponse,
};
use tower_http::cors::CorsLayer;
use tracing::info;

mod signer;

use signer::CredentialSigner;

#[derive(Clone)]
struct AppState {
    signer: Arc<CredentialSigner>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .init();

    let listen = std::env::var("ZKNYM_LISTEN").unwrap_or_else(|_| "127.0.0.1:8089".to_string());
    let addr: SocketAddr = listen.parse()?;

    let signer = Arc::new(CredentialSigner::new()?);
    info!("nym-mock-zknym ecash signer ready");
    let state = AppState { signer };

    let app = Router::new()
        .route(
            "/api/public/v1/directory/zk-nyms/ticketbook/partial-verification-keys",
            get(partial_verification_keys),
        )
        .route(
            "/api/public/v1/account/{account}/device/{device}/zknym",
            post(zknym_post).get(zknym_list),
        )
        .route(
            "/api/public/v1/account/{account}/device/{device}/zknym/available",
            get(zknym_available),
        )
        .route(
            "/api/public/v1/account/{account}/device/{device}/zknym/{id}",
            get(zknym_get).delete(zknym_delete),
        )
        .layer(CorsLayer::permissive())
        .with_state(state);

    info!("listening on {addr}");
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;
    Ok(())
}

async fn partial_verification_keys(
    State(state): State<AppState>,
) -> Json<PartialVerificationKeysResponse> {
    Json(state.signer.partial_verification_keys())
}

async fn zknym_post(
    State(state): State<AppState>,
    Path((account, device)): Path<(String, String)>,
    Json(body): Json<RequestZkNymRequestBody>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    match state.signer.request_zknym(&account, &device, body) {
        Ok(post) => Ok(Json(serde_json::to_value(post).unwrap())),
        Err(e) => {
            tracing::error!("zknym post failed: {e:#}");
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

async fn zknym_get(
    State(state): State<AppState>,
    Path((account, device, id)): Path<(String, String, String)>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    match state.signer.get_zknym(&account, &device, &id) {
        Some(z) => Ok(Json(serde_json::to_value(z).unwrap())),
        None => Err(StatusCode::NOT_FOUND),
    }
}

async fn zknym_available(
    State(state): State<AppState>,
    Path((account, device)): Path<(String, String)>,
) -> Json<NymVpnZkNymResponse> {
    Json(state.signer.list_available(&account, &device))
}

async fn zknym_list(
    State(state): State<AppState>,
    Path((_account, _device)): Path<(String, String)>,
) -> Json<NymVpnZkNymResponse> {
    Json(state.signer.list_device_zknym())
}

async fn zknym_delete(
    State(state): State<AppState>,
    Path((account, device, id)): Path<(String, String, String)>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    match state.signer.confirm_download(&account, &device, &id) {
        Ok(ok) => Ok(Json(serde_json::to_value(ok).unwrap())),
        Err(e) => {
            tracing::error!("zknym delete failed: {e:#}");
            Err(StatusCode::NOT_FOUND)
        }
    }
}

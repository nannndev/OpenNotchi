use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use std::fmt;

/// Typed error for gateway store, routing, and HTTP handlers.
#[derive(Debug, Clone)]
pub enum GatewayError {
    BadRequest(String),
    Unauthorized(String),
    NotFound(String),
    BadGateway(String),
    Internal(String),
}

impl fmt::Display for GatewayError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadRequest(msg) | Self::Unauthorized(msg) | Self::NotFound(msg) | Self::BadGateway(msg) | Self::Internal(msg) => {
                write!(f, "{msg}")
            }
        }
    }
}

impl std::error::Error for GatewayError {}

impl From<String> for GatewayError {
    fn from(msg: String) -> Self {
        Self::Internal(msg)
    }
}

impl IntoResponse for GatewayError {
    fn into_response(self) -> Response {
        let (status, msg) = match self {
            Self::BadRequest(m) => (StatusCode::BAD_REQUEST, m),
            Self::Unauthorized(m) => (StatusCode::UNAUTHORIZED, m),
            Self::NotFound(m) => (StatusCode::NOT_FOUND, m),
            Self::BadGateway(m) => (StatusCode::BAD_GATEWAY, m),
            Self::Internal(m) => (StatusCode::INTERNAL_SERVER_ERROR, m),
        };
        (status, Json(json!({ "detail": msg, "error": { "message": msg } }))).into_response()
    }
}

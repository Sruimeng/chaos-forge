use axum::{
    body::Body,
    extract::{Path, State},
    http::header,
    response::Response,
    routing::{get, post},
    Json, Router,
};
use serde_json::json;

use crate::error::{AppError, Result};
use crate::models::TripoTaskRequest;
use crate::AppState;

const FORBIDDEN_WORDS: [&str; 4] = ["weapon", "gun", "bomb", "violence"];

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/v1/tripo/task", post(create_task))
        .route("/v1/tripo/task/:task_id", get(get_task))
}

async fn create_task(
    State(state): State<AppState>,
    Json(payload): Json<TripoTaskRequest>,
) -> Result<Response> {
    validate_prompt(&payload.prompt)?;

    let body = json!({
        "type": "text_to_model",
        "prompt": payload.prompt,
        "model_version": payload.model_version.unwrap_or_else(|| "default".to_string()),
        "quality": payload.quality.unwrap_or_else(|| "medium".to_string()),
    });

    let url = format!("{}/task", state.config.tripo_base_url);
    let resp = state
        .http_client
        .post(url)
        .bearer_auth(&state.config.tripo_api_key)
        .json(&body)
        .send()
        .await?;

    forward_response(resp).await
}

async fn get_task(
    State(state): State<AppState>,
    Path(task_id): Path<String>,
) -> Result<Response> {
    let url = format!("{}/task/{}", state.config.tripo_base_url, task_id);
    let resp = state
        .http_client
        .get(url)
        .bearer_auth(&state.config.tripo_api_key)
        .send()
        .await?;

    forward_response(resp).await
}

fn validate_prompt(prompt: &str) -> Result<()> {
    let length = prompt.len();
    if length < 10 || length > 500 {
        return Err(AppError::bad_request("prompt length must be 10-500"));
    }

    let prompt_lower = prompt.to_lowercase();
    for word in FORBIDDEN_WORDS {
        if prompt_lower.contains(word) {
            return Err(AppError::bad_request("prompt contains forbidden content"));
        }
    }

    Ok(())
}

async fn forward_response(resp: reqwest::Response) -> Result<Response> {
    let status = resp.status();
    let content_type = resp.headers().get(header::CONTENT_TYPE).cloned();
    let bytes = resp.bytes().await?;

    let mut response = Response::new(Body::from(bytes));
    *response.status_mut() = status;
    if let Some(value) = content_type {
        response.headers_mut().insert(header::CONTENT_TYPE, value);
    }

    Ok(response)
}

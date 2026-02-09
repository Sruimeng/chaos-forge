use axum::{extract::{Path, State}, routing::{get, post}, Json, Router};
use chrono::Utc;
use uuid::Uuid;

use crate::error::{AppError, Result};
use crate::models::{CreateWeaponRequest, SharedWeapon, Weapon};
use crate::AppState;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/v1/weapons", post(create_weapon))
        .route("/v1/weapons/:id", get(get_weapon))
        .route("/v1/weapons/:id/share", post(share_weapon))
        .route("/v1/share/:share_id", get(get_shared_weapon))
}

async fn create_weapon(
    State(state): State<AppState>,
    Json(payload): Json<CreateWeaponRequest>,
) -> Result<Json<Weapon>> {
    let CreateWeaponRequest {
        owner_id,
        prompt,
        model_url,
        model_path,
        bug_level,
        pitch_text,
        sale_success,
        tripo_task_id,
        metadata,
        share,
    } = payload;

    let prompt = prompt.trim().to_string();
    if prompt.is_empty() {
        return Err(AppError::bad_request("prompt is required"));
    }
    if prompt.len() < 10 || prompt.len() > 500 {
        return Err(AppError::bad_request("prompt length must be 10-500"));
    }

    let share = share.unwrap_or(false);
    let share_id = if share { Some(Uuid::new_v4()) } else { None };
    let shared_at = if share { Some(Utc::now()) } else { None };

    let weapon = sqlx::query_as::<_, Weapon>(
        r#"
        INSERT INTO weapons (
            owner_id,
            prompt,
            model_url,
            model_path,
            bug_level,
            pitch_text,
            sale_success,
            tripo_task_id,
            metadata,
            share_id,
            shared_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        RETURNING
            id,
            owner_id,
            prompt,
            model_url,
            model_path,
            bug_level,
            pitch_text,
            sale_success,
            tripo_task_id,
            metadata,
            share_id,
            created_at,
            shared_at
        "#,
    )
    .bind(owner_id)
    .bind(prompt)
    .bind(model_url)
    .bind(model_path)
    .bind(bug_level)
    .bind(pitch_text)
    .bind(sale_success)
    .bind(tripo_task_id)
    .bind(metadata)
    .bind(share_id)
    .bind(shared_at)
    .fetch_one(&state.pool)
    .await?;

    Ok(Json(weapon))
}

async fn get_weapon(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<Weapon>> {
    let weapon = sqlx::query_as::<_, Weapon>(
        r#"
        SELECT
            id,
            owner_id,
            prompt,
            model_url,
            model_path,
            bug_level,
            pitch_text,
            sale_success,
            tripo_task_id,
            metadata,
            share_id,
            created_at,
            shared_at
        FROM weapons
        WHERE id = $1
        "#,
    )
    .bind(id)
    .fetch_optional(&state.pool)
    .await?;

    match weapon {
        Some(record) => Ok(Json(record)),
        None => Err(AppError::not_found("weapon not found")),
    }
}

async fn share_weapon(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> Result<Json<Weapon>> {
    let weapon = sqlx::query_as::<_, Weapon>(
        r#"
        UPDATE weapons
        SET
            share_id = COALESCE(share_id, gen_random_uuid()),
            shared_at = COALESCE(shared_at, now())
        WHERE id = $1
        RETURNING
            id,
            owner_id,
            prompt,
            model_url,
            model_path,
            bug_level,
            pitch_text,
            sale_success,
            tripo_task_id,
            metadata,
            share_id,
            created_at,
            shared_at
        "#,
    )
    .bind(id)
    .fetch_optional(&state.pool)
    .await?;

    match weapon {
        Some(record) => Ok(Json(record)),
        None => Err(AppError::not_found("weapon not found")),
    }
}

async fn get_shared_weapon(
    State(state): State<AppState>,
    Path(share_id): Path<Uuid>,
) -> Result<Json<SharedWeapon>> {
    let weapon = sqlx::query_as::<_, SharedWeapon>(
        r#"
        SELECT
            id,
            prompt,
            model_url,
            bug_level,
            pitch_text,
            sale_success,
            metadata,
            created_at,
            shared_at
        FROM weapons
        WHERE share_id = $1
        "#,
    )
    .bind(share_id)
    .fetch_optional(&state.pool)
    .await?;

    match weapon {
        Some(record) => Ok(Json(record)),
        None => Err(AppError::not_found("share not found")),
    }
}

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Serialize, FromRow)]
pub struct Weapon {
    pub id: Uuid,
    pub owner_id: Option<String>,
    pub prompt: String,
    pub model_url: Option<String>,
    pub model_path: Option<String>,
    pub bug_level: Option<f32>,
    pub pitch_text: Option<String>,
    pub sale_success: Option<bool>,
    pub tripo_task_id: Option<String>,
    pub metadata: Option<Value>,
    pub share_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub shared_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, FromRow)]
pub struct SharedWeapon {
    pub id: Uuid,
    pub prompt: String,
    pub model_url: Option<String>,
    pub bug_level: Option<f32>,
    pub pitch_text: Option<String>,
    pub sale_success: Option<bool>,
    pub metadata: Option<Value>,
    pub created_at: DateTime<Utc>,
    pub shared_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize)]
pub struct CreateWeaponRequest {
    pub owner_id: Option<String>,
    pub prompt: String,
    pub model_url: Option<String>,
    pub model_path: Option<String>,
    pub bug_level: Option<f32>,
    pub pitch_text: Option<String>,
    pub sale_success: Option<bool>,
    pub tripo_task_id: Option<String>,
    pub metadata: Option<Value>,
    pub share: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct ShareWeaponRequest {
    pub share: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct TripoTaskRequest {
    pub prompt: String,
    pub model_version: Option<String>,
    pub quality: Option<String>,
}

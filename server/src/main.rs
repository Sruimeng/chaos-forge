mod config;
mod db;
mod error;
mod models;
mod routes;

use std::sync::Arc;

use axum::Router;
use sqlx::PgPool;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing_subscriber::EnvFilter;

use crate::config::Config;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub http_client: reqwest::Client,
    pub config: Arc<Config>,
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .init();

    let config = match Config::from_env() {
        Ok(config) => config,
        Err(err) => {
            eprintln!("Config error: {err}");
            std::process::exit(1);
        }
    };

    let pool = match db::connect(&config.database_url).await {
        Ok(pool) => pool,
        Err(err) => {
            eprintln!("Database connection error: {err}");
            std::process::exit(1);
        }
    };

    if let Err(err) = db::run_migrations(&pool).await {
        eprintln!("Migration error: {err}");
        std::process::exit(1);
    }

    let state = AppState {
        pool,
        http_client: reqwest::Client::new(),
        config: Arc::new(config),
    };

    let app = Router::new()
        .merge(routes::routes())
        .with_state(state)
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http());

    let addr = state.config.bind_addr;
    tracing::info!("listening on {}", addr);

    let listener = match tokio::net::TcpListener::bind(addr).await {
        Ok(listener) => listener,
        Err(err) => {
            eprintln!("Bind error: {err}");
            std::process::exit(1);
        }
    };

    if let Err(err) = axum::serve(listener, app).await {
        eprintln!("Server error: {err}");
        std::process::exit(1);
    }
}

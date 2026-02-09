use axum::Router;

use crate::AppState;

mod health;
mod tripo;
mod weapons;

pub fn routes() -> Router<AppState> {
    Router::new()
        .merge(health::routes())
        .merge(tripo::routes())
        .merge(weapons::routes())
}

# Godot Backend (Rust + Postgres)

## Setup

1. Copy `.env.example` to `.env` and fill `DATABASE_URL` + `TRIPO_API_KEY`.
2. Run the server with Cargo:

```bash
cargo run
```

The server auto-runs SQL migrations on startup.

## Endpoints

- `GET /v1/health`
- `POST /v1/tripo/task`
- `GET /v1/tripo/task/:task_id`
- `POST /v1/weapons`
- `GET /v1/weapons/:id`
- `POST /v1/weapons/:id/share`
- `GET /v1/share/:share_id`

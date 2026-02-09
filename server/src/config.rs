use std::env;
use std::net::SocketAddr;

#[derive(Clone, Debug)]
pub struct Config {
    pub bind_addr: SocketAddr,
    pub database_url: String,
    pub tripo_base_url: String,
    pub tripo_api_key: String,
}

impl Config {
    pub fn from_env() -> Result<Self, String> {
        let bind_addr = env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".to_string());
        let bind_addr: SocketAddr = bind_addr
            .parse()
            .map_err(|_| format!("Invalid BIND_ADDR: {bind_addr}"))?;

        let database_url = env::var("DATABASE_URL")
            .map_err(|_| "DATABASE_URL is required".to_string())?;

        let tripo_base_url = env::var("TRIPO_BASE_URL")
            .unwrap_or_else(|_| "https://api.tripo3d.ai/v2/openapi".to_string());

        let tripo_api_key = env::var("TRIPO_API_KEY")
            .map_err(|_| "TRIPO_API_KEY is required".to_string())?;

        Ok(Self {
            bind_addr,
            database_url,
            tripo_base_url,
            tripo_api_key,
        })
    }
}

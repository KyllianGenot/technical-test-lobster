use config::{Config, ConfigError, File};
use serde::Deserialize;
use diesel::pg::PgConnection;
use diesel::r2d2::ConnectionManager;
use std::path::Path;
use crate::utils::eth::connect_to_node;
use crate::services::indexer::start_indexing;
use env_logger;
use log::{error, info};

mod schema;
mod models;
mod repositories;
mod utils;
mod services;

#[derive(Debug, Deserialize)]
struct Settings {
    ethereum: Ethereum,
    database: Database,
    api: Api,
}

#[derive(Debug, Deserialize)]
struct Ethereum {
    node_url: String,
    token_address: String,
}

#[derive(Debug, Deserialize)]
struct Database {
    url: String,
}

#[derive(Debug, Deserialize)]
struct Api {
    #[serde(default = "default_port")]
    port: u16,
}

fn default_port() -> u16 {
    8080
}

fn load_config() -> Result<Settings, ConfigError> {
    let config_path = "config/config.toml";
    if !Path::new(config_path).exists() {
        return Err(ConfigError::Message(format!(
            "Configuration file '{}' not found. Please create it with appropriate settings.",
            config_path
        )));
    }
    Config::builder()
        .add_source(File::with_name(config_path))
        .set_default("api.port", 8080)?
        .build()?
        .try_deserialize()
}

type DbPool = diesel::r2d2::Pool<ConnectionManager<PgConnection>>;

fn create_db_pool(database_url: &str) -> Result<DbPool, diesel::r2d2::Error> {
    let manager = ConnectionManager::<PgConnection>::new(database_url);
    diesel::r2d2::Pool::builder().build(manager).map_err(|e| {
        diesel::r2d2::Error::ConnectionError(diesel::ConnectionError::BadConnection(e.to_string()))
    })
}

#[tokio::main]
async fn main() {
    env_logger::init();

    let settings = load_config().unwrap_or_else(|e| {
        eprintln!("Failed to load configuration: {}", e);
        std::process::exit(1);
    });
    info!("Loaded configuration: {:?}", settings);

    let pool = create_db_pool(&settings.database.url).unwrap_or_else(|e| {
        eprintln!("Database pool failed: {}", e);
        std::process::exit(1);
    });
    info!("Database pool initialized successfully: {:?}", pool);

    let transfer_repo = repositories::transfer_repo::TransferRepo::new(pool.clone());
    info!("TransferRepo initialized: {:?}", transfer_repo);

    match connect_to_node(&settings.ethereum.node_url).await {
        Ok(web3) => info!("Connected to Ethereum node: {:?}", web3.eth().chain_id().await),
        Err(e) => eprintln!("Failed to connect to Ethereum node: {}", e),
    }

    tokio::spawn(async move {
        if let Err(e) = start_indexing(
            pool,
            settings.ethereum.node_url.clone(),
            settings.ethereum.token_address.clone(),
        ).await {
            error!("Indexer failed: {}", e);
        }
    });

    info!("Indexer started. Running indefinitely...");
    tokio::time::sleep(tokio::time::Duration::from_secs(3600)).await;
}
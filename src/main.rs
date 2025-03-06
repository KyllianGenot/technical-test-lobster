use config::{Config, ConfigError, File};
use serde::Deserialize;
use diesel::pg::PgConnection;
use diesel::r2d2::ConnectionManager;
use std::path::Path;

mod schema;
mod models;

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct Settings {
    ethereum: Ethereum,
    database: Database,
    api: Api,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct Ethereum {
    node_url: String,
    token_address: String,
}

#[derive(Debug, Deserialize)]
struct Database {
    url: String,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
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

    let settings = Config::builder()
        .add_source(File::with_name(config_path))
        .set_default("api.port", 8080)?
        .build()?;

    settings.try_deserialize()
}

type DbPool = diesel::r2d2::Pool<ConnectionManager<PgConnection>>;

fn create_db_pool(database_url: &str) -> Result<DbPool, diesel::r2d2::Error> {
    let manager = ConnectionManager::<PgConnection>::new(database_url);
    diesel::r2d2::Pool::builder()
        .build(manager)
        .map_err(|e| diesel::r2d2::Error::ConnectionError(
            diesel::ConnectionError::BadConnection(e.to_string())
        ))
}

fn main() {
    // Load configuration
    let settings = match load_config() {
        Ok(config) => config,
        Err(e) => {
            eprintln!("Failed to load configuration: {}", e);
            std::process::exit(1);
        }
    };

    println!("Loaded configuration: {:?}", settings);

    match create_db_pool(&settings.database.url) {
        Ok(pool) => println!("Database pool initialized successfully: {:?}", pool),
        Err(e) => println!("Database pool failed (expected without a real DB): {}", e),
    };

    println!("Test complete. Config loading works!");
}
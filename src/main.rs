use diesel::pg::PgConnection;
use diesel::r2d2::ConnectionManager;
use dotenv::dotenv;
use std::env;
use crate::services::indexer::start_indexing;
use crate::api::eth_scope;
use crate::utils::eth::connect_to_node;
use actix_web::{App, HttpServer, web};
use actix_cors::Cors;
use actix_files::Files;
use env_logger;
use log::{error, info};
use tokio::sync::broadcast;

mod schema;
mod models;
mod repositories;
mod utils;
mod services;
mod api;

type DbPool = diesel::r2d2::Pool<ConnectionManager<PgConnection>>;

fn create_db_pool(database_url: &str) -> Result<DbPool, diesel::r2d2::Error> {
    let manager = ConnectionManager::<PgConnection>::new(database_url);
    diesel::r2d2::Pool::builder().build(manager).map_err(|e| {
        diesel::r2d2::Error::ConnectionError(diesel::ConnectionError::BadConnection(e.to_string()))
    })
}

#[tokio::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();
    
    env_logger::init();
    info!("Starting Main Application");

    let database_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set in .env file");
    
    let ethereum_node_url = env::var("ETHEREUM_NODE_URL")
        .expect("ETHEREUM_NODE_URL must be set in .env file");
    
    let ethereum_token_address = env::var("ETHEREUM_TOKEN_ADDRESS")
        .expect("ETHEREUM_TOKEN_ADDRESS must be set in .env file");
    
    let api_port = env::var("API_PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse::<u16>()
        .unwrap_or(8080);

    info!("Using database URL: {}", database_url);
    info!("Using Ethereum node URL: {}", ethereum_node_url);
    info!("Using token address: {}", ethereum_token_address);
    info!("Using API port: {}", api_port);

    let pool = create_db_pool(&database_url).unwrap_or_else(|e| {
        eprintln!("Database pool failed: {}", e);
        std::process::exit(1);
    });
    info!("Database pool initialized successfully");

    let _transfer_repo = repositories::transfer_repo::TransferRepo::new(pool.clone());
    info!("TransferRepo initialized");

    match connect_to_node(&ethereum_node_url).await {
        Ok(web3) => info!("Connected to Ethereum node: {:?}", web3.eth().chain_id().await),
        Err(e) => eprintln!("Failed to connect to Ethereum node: {}", e),
    }

    let (shutdown_tx, shutdown_rx) = broadcast::channel(1);

    let indexer_shutdown_rx = shutdown_rx;
    let indexer_pool = pool.clone();
    let indexer_node_url = ethereum_node_url.clone();
    let indexer_token_address = ethereum_token_address.clone();

    tokio::spawn(async move {
        if let Err(e) = start_indexing(
            indexer_pool,
            indexer_node_url,
            indexer_token_address,
            indexer_shutdown_rx,
        ).await {
            error!("Indexer failed: {}", e);
        }
    });

    info!("Starting API server on port {}", api_port);
    let server = HttpServer::new(move || {
        let app = App::new()
            .wrap(Cors::permissive())
            .app_data(web::Data::new(pool.clone()))
            .service(eth_scope());
        app.service(Files::new("/", "frontend/dist").index_file("index.html"))
    })
    .bind(("127.0.0.1", api_port))?
    .run();

    let result = server.await;

    let _ = shutdown_tx.send(());

    result
}
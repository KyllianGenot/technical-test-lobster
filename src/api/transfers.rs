use actix_web::{get, web, HttpResponse, Responder};
use serde::{Deserialize, Serialize};
use diesel::r2d2::ConnectionManager;
use diesel::pg::PgConnection;
use crate::repositories::transfer_repo::TransferRepo;
use crate::models::transfer::Transfer;
use log::error;

/// Query parameters for filtering transfers by sender or recipient.
#[derive(Deserialize)]
pub struct TransferQuery {
    sender: Option<String>,
    recipient: Option<String>,
}

/// Response format for the transfers API endpoint.
#[derive(Serialize)]
pub struct TransferResponse {
    token: TokenInfo,
    transfers: Vec<Transfer>,
}

/// Token metadata included in the API response.
#[derive(Serialize)]
pub struct TokenInfo {
    decimals: u8,
    symbol: String,
}

/// API endpoint to retrieve transfer events with optional filters.
#[get("/transfers")]
async fn get_transfers(
    query: web::Query<TransferQuery>,
    pool: web::Data<diesel::r2d2::Pool<ConnectionManager<PgConnection>>>,
) -> impl Responder {
    let transfer_repo = TransferRepo::new(pool.as_ref().clone());
    
    match transfer_repo.get_transfers(query.sender.clone(), query.recipient.clone()).await {
        Ok(transfers) => {
            let response = TransferResponse {
                token: TokenInfo {
                    decimals: 18,
                    symbol: "LOB".to_string(),
                },
                transfers,
            };
            HttpResponse::Ok().json(response)
        }
        Err(e) => {
            error!("Failed to fetch transfers: {}", e);
            HttpResponse::InternalServerError().json(format!("Error fetching transfers: {}", e))
        }
    }
}
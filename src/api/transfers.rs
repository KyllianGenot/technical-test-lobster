use actix_web::{get, web, HttpResponse, Responder};
use serde::{Deserialize, Serialize};
use diesel::r2d2::ConnectionManager;
use diesel::pg::PgConnection;
use crate::repositories::transfer_repo::TransferRepo;
use crate::models::transfer::Transfer;
use log::error;

#[derive(Deserialize)]
pub struct TransferQuery {
    sender: Option<String>,
    recipient: Option<String>,
}

#[derive(Serialize)]
pub struct TransferResponse {
    token: TokenInfo,
    transfers: Vec<Transfer>,
}

#[derive(Serialize)]
pub struct TokenInfo {
    decimals: u8,
    symbol: String,
}

#[get("/transfers")]
async fn get_transfers(
    query: web::Query<TransferQuery>,
    pool: web::Data<diesel::r2d2::Pool<ConnectionManager<PgConnection>>>,
) -> impl Responder {
    let transfer_repo = TransferRepo::new(pool.as_ref().clone()); // Correction ici
    
    match transfer_repo.get_transfers(query.sender.clone(), query.recipient.clone()).await {
        Ok(transfers) => {
            let response = TransferResponse {
                token: TokenInfo {
                    decimals: 18,
                    symbol: "DEMO".to_string(),
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
use diesel::prelude::*;
use diesel::r2d2::ConnectionManager;
use tokio::task;
use crate::models::transfer::Transfer;
use crate::schema::transfers;

#[derive(Debug)]
pub struct TransferRepo {
    pub pool: diesel::r2d2::Pool<ConnectionManager<PgConnection>>,
}

impl TransferRepo {
    pub fn new(pool: diesel::r2d2::Pool<ConnectionManager<PgConnection>>) -> Self {
        TransferRepo { pool }
    }

    // Change &Transfer to Transfer to take ownership
    pub async fn insert_transfer(&self, transfer: Transfer) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let mut conn = self.pool.get()?; // Declare as mutable
        task::spawn_blocking(move || {
            diesel::insert_into(transfers::table)
                .values(&transfer) // Use reference here since Diesel expects Insertable
                .execute(&mut conn) // Use mutable connection
                .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?; // Map Diesel error
            Ok(())
        })
        .await?
    }

    pub async fn get_transfers(
        &self,
        sender: Option<String>,
        recipient: Option<String>,
    ) -> Result<Vec<Transfer>, Box<dyn std::error::Error + Send + Sync>> {
        let mut conn = self.pool.get()?; // Declare as mutable
        let sender = sender.clone();
        let recipient = recipient.clone();
        task::spawn_blocking(move || {
            let mut query = transfers::table.order(transfers::block_number.desc()).into_boxed();
            if let Some(s) = sender {
                query = query.filter(transfers::sender.eq(s));
            }
            if let Some(r) = recipient {
                query = query.filter(transfers::recipient.eq(r));
            }
            query
                .load::<Transfer>(&mut conn) // Use mutable connection
                .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>) // Map Diesel error
        })
        .await?
    }
}
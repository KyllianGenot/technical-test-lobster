use diesel::prelude::*;
use serde::Serialize;
use crate::schema::transfers;

/// Represents a transfer event retrieved from the database.
#[derive(Queryable, Serialize, Debug)]
#[diesel(table_name = transfers)]
pub struct Transfer {
    pub id: i32,
    pub sender: String,
    pub recipient: String,
    pub amount: String,
    pub block_number: i64,
    pub tx_hash: String,
}

/// Represents a new transfer event to be inserted into the database.
#[derive(Insertable, Debug)]
#[diesel(table_name = transfers)]
pub struct NewTransfer {
    pub sender: String,
    pub recipient: String,
    pub amount: String,
    pub block_number: i64,
    pub tx_hash: String,
}
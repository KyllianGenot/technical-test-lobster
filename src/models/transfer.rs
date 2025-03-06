use diesel::prelude::*;
use serde::Serialize;
use crate::schema::transfers;

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

#[derive(Insertable, Debug)]
#[diesel(table_name = transfers)]
pub struct NewTransfer {
    pub sender: String,
    pub recipient: String,
    pub amount: String,
    pub block_number: i64,
    pub tx_hash: String,
}
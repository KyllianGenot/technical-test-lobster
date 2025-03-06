use diesel::r2d2::ConnectionManager;
use diesel::pg::PgConnection;
use tokio::time::{interval, Duration};
use web3::types::{FilterBuilder, H256};
use crate::repositories::transfer_repo::TransferRepo;
use crate::utils::eth::{connect_to_node, decode_transfer_log};
use crate::models::transfer::Transfer;

pub async fn start_indexing(
    pool: diesel::r2d2::Pool<ConnectionManager<PgConnection>>,
    node_url: String,
    token_address: String,
) -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> { // Add Send + Sync bounds
    let web3 = connect_to_node(&node_url).await?;
    let eth = web3.eth();

    let transfer_topic = H256::from_slice(
        &hex::decode("ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")?,
    );
    let filter = FilterBuilder::default()
        .address(vec![token_address.parse()?])
        .topics(Some(vec![transfer_topic]), None, None, None)
        .build();

    let transfer_repo = TransferRepo::new(pool);

    let mut interval = interval(Duration::from_secs(5));
    loop {
        interval.tick().await;

        let logs = eth.logs(filter.clone()).await?;
        for log in logs {
            match decode_transfer_log(log.clone()) {
                Ok((sender, recipient, amount)) => {
                    let transfer = Transfer {
                        id: 0,
                        sender,
                        recipient,
                        amount,
                        block_number: log.block_number.unwrap_or_default().as_u64() as i64,
                        tx_hash: format!("{:x}", log.transaction_hash.unwrap_or_default()),
                    };

                    if let Err(e) = transfer_repo.insert_transfer(transfer).await {
                        eprintln!("Failed to insert transfer: {}", e);
                    }
                }
                Err(e) => eprintln!("Failed to decode log: {}", e),
            }
        }
    }
}
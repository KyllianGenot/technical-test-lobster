use web3::types::{H256, FilterBuilder, BlockNumber, H160, U64};
use diesel::r2d2::ConnectionManager;
use diesel::pg::PgConnection;
use tokio::time::{interval, Duration};
use crate::repositories::transfer_repo::TransferRepo;
use crate::utils::eth::{connect_to_node, decode_transfer_log};
use crate::models::transfer::NewTransfer;
use log::{info, error};
use hex;

async fn find_deployment_block(
    web3: &web3::Web3<web3::transports::Http>,
    token_address: H160,
    transfer_topic: H256,
) -> Result<u64, Box<dyn std::error::Error + Send + Sync + 'static>> {
    let eth = web3.eth();
    let latest_block = eth.block_number().await?.as_u64();
    let mut low = 0;
    let mut high = latest_block;
    let mut deployment_block = latest_block;

    info!("Searching for deployment block of token 0x{}", hex::encode(token_address.as_bytes()));

    while low <= high {
        let mid = (low + high) / 2;
        let filter = FilterBuilder::default()
            .address(vec![token_address])
            .topics(Some(vec![transfer_topic]), None, None, None)
            .from_block(BlockNumber::Number(U64::from(mid)))
            .to_block(BlockNumber::Number(U64::from(high)))
            .build();

        let logs = eth.logs(filter).await?;
        info!("Checked blocks {} to {}: {} logs found", mid, high, logs.len());

        if logs.is_empty() {
            high = if mid == 0 { 0 } else { mid - 1 };
        } else {
            deployment_block = logs.iter()
                .filter_map(|log| log.block_number.map(|num| num.as_u64()))
                .min()
                .unwrap_or(deployment_block);
            low = mid + 1;
        }
    }

    if deployment_block == latest_block {
        info!("No transfers found, starting from latest block {}", latest_block);
        return Ok(latest_block);
    }

    info!("Detected deployment block: {}", deployment_block);
    Ok(deployment_block)
}

async fn backfill_transfers(
    pool: diesel::r2d2::Pool<ConnectionManager<PgConnection>>,
    web3: web3::Web3<web3::transports::Http>,
    token_address: String,
    start_block: u64,
) -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
    let eth = web3.eth();
    let token_address_h160 = token_address.parse::<H160>()?;
    let transfer_topic = H256::from_slice(
        &hex::decode("ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")?,
    );
    let transfer_repo = TransferRepo::new(pool);
    let latest_block = eth.block_number().await?;
    info!("Backfilling transfers from block {} to {}", start_block, latest_block);
    let mut from_block = U64::from(start_block);
    let to_block = latest_block;
    const BATCH_SIZE: u64 = 1000;

    while from_block <= to_block {
        let batch_end = (from_block + BATCH_SIZE - 1).min(to_block);
        let filter = FilterBuilder::default()
            .address(vec![token_address_h160])
            .topics(Some(vec![transfer_topic]), None, None, None)
            .from_block(BlockNumber::Number(from_block))
            .to_block(BlockNumber::Number(batch_end))
            .build();
        info!("Fetching historical logs from block {} to {}", from_block, batch_end);
        let logs = eth.logs(filter).await?;
        info!("Fetched {} historical logs from block {} to {}", logs.len(), from_block, batch_end);
        for log in logs {
            match decode_transfer_log(log.clone()) {
                Ok((sender, recipient, amount)) => {
                    let transfer = NewTransfer {
                        sender,
                        recipient,
                        amount,
                        block_number: log.block_number.unwrap_or_default().as_u64() as i64,
                        tx_hash: format!("0x{:x}", log.transaction_hash.unwrap_or_default()),
                    };
                    if let Err(e) = transfer_repo.insert_transfer(transfer).await {
                        error!("Failed to insert historical transfer: {}", e);
                    } else {
                        info!("Inserted historical transfer: tx_hash={}", log.transaction_hash.unwrap_or_default());
                    }
                }
                Err(e) => error!("Failed to decode historical log: {}", e),
            }
        }
        from_block = batch_end + 1;
    }
    info!("Backfill completed up to block {}", to_block);
    Ok(())
}

pub async fn start_indexing(
    pool: diesel::r2d2::Pool<ConnectionManager<PgConnection>>,
    node_url: String,
    token_address: String,
) -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
    let web3 = connect_to_node(&node_url).await?;
    let eth = web3.eth();
    let token_address_h160 = token_address.parse::<H160>()?;
    info!("Monitoring token address: 0x{}", hex::encode(token_address_h160.as_bytes()));
    let transfer_topic = H256::from_slice(
        &hex::decode("ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")?,
    );
    let transfer_repo = TransferRepo::new(pool.clone());
    let deployment_block = find_deployment_block(&web3, token_address_h160, transfer_topic).await?;
    backfill_transfers(pool.clone(), web3.clone(), token_address.clone(), deployment_block).await?;
    let mut last_block = eth.block_number().await?;
    let mut interval = interval(Duration::from_secs(5));
    let test_filter = FilterBuilder::default()
        .address(vec![token_address_h160])
        .topics(Some(vec![transfer_topic]), None, None, None)
        .from_block(BlockNumber::Number(U64::from(deployment_block)))
        .to_block(BlockNumber::Number(U64::from(deployment_block)))
        .build();
    match eth.logs(test_filter).await {
        Ok(logs) => info!("Test fetch: {} logs at block {}", logs.len(), deployment_block),
        Err(e) => error!("Test fetch failed: {}", e),
    }
    loop {
        info!("Starting indexing loop iteration");
        interval.tick().await;
        info!("Checking for new blocks...");
        let latest_block = match eth.block_number().await {
            Ok(block) => block,
            Err(e) => {
                error!("Failed to get latest block: {}", e);
                continue;
            }
        };
        info!("Current latest block: {}", latest_block);
        if latest_block <= last_block {
            info!("No new blocks to process (latest: {}, last: {})", latest_block, last_block);
            continue;
        }
        let mut from_block = last_block + 1;
        let to_block = latest_block;
        const BATCH_SIZE: u64 = 100;
        while from_block <= to_block {
            let batch_end = (from_block + BATCH_SIZE - 1).min(to_block);
            let filter = FilterBuilder::default()
                .address(vec![token_address_h160])
                .topics(Some(vec![transfer_topic]), None, None, None)
                .from_block(BlockNumber::Number(from_block))
                .to_block(BlockNumber::Number(batch_end))
                .build();
            info!("Fetching logs from block {} to {}", from_block, batch_end);
            let logs = match eth.logs(filter).await {
                Ok(logs) => logs,
                Err(e) => {
                    error!("Failed to fetch logs from {} to {}: {}", from_block, batch_end, e);
                    break;
                }
            };
            info!("Fetched {} logs from block {} to {}", logs.len(), from_block, batch_end);
            for log in logs {
                match decode_transfer_log(log.clone()) {
                    Ok((sender, recipient, amount)) => {
                        let transfer = NewTransfer {
                            sender,
                            recipient,
                            amount,
                            block_number: log.block_number.unwrap_or_default().as_u64() as i64,
                            tx_hash: format!("0x{:x}", log.transaction_hash.unwrap_or_default()),
                        };
                        if let Err(e) = transfer_repo.insert_transfer(transfer).await {
                            error!("Failed to insert transfer: {}", e);
                        } else {
                            info!("Inserted transfer: tx_hash={}", log.transaction_hash.unwrap_or_default());
                        }
                    }
                    Err(e) => error!("Failed to decode log: {}", e),
                }
            }
            from_block = batch_end + 1;
        }
        last_block = to_block;
    }
}
use web3::types::{H256, FilterBuilder, BlockNumber, H160, U64};
use diesel::r2d2::ConnectionManager;
use diesel::pg::PgConnection;
use tokio::time::{interval, Duration, sleep};
use crate::repositories::transfer_repo::TransferRepo;
use crate::utils::eth::{connect_to_node, decode_transfer_log};
use crate::models::transfer::NewTransfer;
use log::{info, error, warn};
use hex;
use tokio::sync::broadcast;
use tokio::task;
use std::sync::Arc;

/// Finds the block range containing ERC-20 Transfer events for a token.
async fn find_transfer_blocks(
    web3: &web3::Web3<web3::transports::Http>,
    token_address: H160,
    transfer_topic: H256,
) -> Result<(u64, u64), Box<dyn std::error::Error + Send + Sync + 'static>> {
    let eth = web3.eth();
    let latest_block = eth.block_number().await?.as_u64();
    let start_block = 0;

    info!("Searching for transfer blocks of token 0x{}", hex::encode(token_address.as_bytes()));

    let filter = FilterBuilder::default()
        .address(vec![token_address])
        .topics(Some(vec![transfer_topic]), None, None, None)
        .from_block(BlockNumber::Number(U64::from(start_block)))
        .to_block(BlockNumber::Number(U64::from(latest_block)))
        .build();

    let logs = eth.logs(filter).await?;
    info!("Fetched {} logs from block {} to {}", logs.len(), start_block, latest_block);

    if logs.is_empty() {
        info!("No transfers found, starting from latest block {}", latest_block);
        return Ok((latest_block, latest_block));
    }

    let blocks_with_logs: Vec<u64> = logs.iter()
        .filter_map(|log| log.block_number.map(|num| num.as_u64()))
        .collect();
    let min_block = blocks_with_logs.iter().min().unwrap_or(&latest_block);
    let max_block = blocks_with_logs.iter().max().unwrap_or(&latest_block);

    info!("Detected transfer blocks range: {} to {}", min_block, max_block);
    Ok((*min_block, *max_block))
}

/// Processes a batch of logs and stores transfer events in the database.
async fn process_logs_batch(
    web3: &web3::Web3<web3::transports::Http>,
    transfer_repo: Arc<TransferRepo>,
    token_address: H160,
    transfer_topic: H256,
    from_block: u64,
    to_block: u64,
) -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
    let filter = FilterBuilder::default()
        .address(vec![token_address])
        .topics(Some(vec![transfer_topic]), None, None, None)
        .from_block(BlockNumber::Number(U64::from(from_block)))
        .to_block(BlockNumber::Number(U64::from(to_block)))
        .build();

    info!("Fetching logs from block {} to {}", from_block, to_block);
    let logs = web3.eth().logs(filter).await?;
    info!("Fetched {} logs from block {} to {}", logs.len(), from_block, to_block);

    for log in logs {
        info!("Processing log: block_number={:?}, tx_hash={:?}", log.block_number, log.transaction_hash);
        match decode_transfer_log(log.clone()) {
            Ok((sender, recipient, amount)) => {
                let transfer = NewTransfer {
                    sender,
                    recipient,
                    amount,
                    block_number: log.block_number.unwrap_or_default().as_u64() as i64,
                    tx_hash: format!("0x{:x}", log.transaction_hash.unwrap_or_default()),
                };
                match transfer_repo.insert_transfer(transfer).await {
                    Ok(_) => info!("Inserted historical transfer: tx_hash={}", log.transaction_hash.unwrap_or_default()),
                    Err(e) => error!("Failed to insert historical transfer: {}", e),
                }
            }
            Err(e) => error!("Failed to decode historical log: {}", e),
        }
    }
    Ok(())
}

/// Backfills historical transfer events into the database within a block range.
async fn backfill_transfers(
    pool: diesel::r2d2::Pool<ConnectionManager<PgConnection>>,
    web3: web3::Web3<web3::transports::Http>,
    token_address: String,
    start_block: u64,
    end_block: u64,
) -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
    let eth = web3.eth();
    let token_address_h160 = token_address.parse::<H160>()?;
    let transfer_topic = H256::from_slice(
        &hex::decode("ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")?, // ERC-20 Transfer event topic hash.
    );
    let transfer_repo = Arc::new(TransferRepo::new(pool));
    let latest_block = eth.block_number().await?.as_u64();
    let actual_end_block = end_block.min(latest_block);
    info!("Backfilling transfers from block {} to {}", start_block, actual_end_block);

    let mut tasks = Vec::new();
    const BATCH_SIZE: u64 = 100_000; // Process blocks in batches to avoid overloading the node.

    let mut from_block = start_block;
    while from_block <= actual_end_block {
        let to_block = (from_block + BATCH_SIZE - 1).min(actual_end_block);
        let web3_clone = web3.clone();
        let transfer_repo_clone = Arc::clone(&transfer_repo);
        let token_address_h160_clone = token_address_h160;
        let transfer_topic_clone = transfer_topic;

        let task = task::spawn(async move {
            if let Err(e) = process_logs_batch(
                &web3_clone,
                transfer_repo_clone,
                token_address_h160_clone,
                transfer_topic_clone,
                from_block,
                to_block,
            ).await {
                error!("Error processing batch {} to {}: {}", from_block, to_block, e);
            }
        });
        tasks.push(task);

        from_block = to_block + 1;
    }

    for task in tasks {
        task.await?;
    }

    info!("Backfill completed up to block {}", latest_block);
    Ok(())
}

/// Starts the indexer to monitor and store ERC-20 Transfer events.
pub async fn start_indexing(
    pool: diesel::r2d2::Pool<ConnectionManager<PgConnection>>,
    node_url: String,
    token_address: String,
    mut shutdown_rx: broadcast::Receiver<()>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
    let web3 = connect_to_node(&node_url).await?;
    let eth = web3.eth();
    let token_address_h160 = token_address.parse::<H160>()?;
    info!("Monitoring token address: 0x{}", hex::encode(token_address_h160.as_bytes()));
    let transfer_topic = H256::from_slice(
        &hex::decode("ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")?, // ERC-20 Transfer event topic hash.
    );
    let transfer_repo = Arc::new(TransferRepo::new(pool.clone()));
    let (min_block, max_block) = find_transfer_blocks(&web3, token_address_h160, transfer_topic).await?;
    backfill_transfers(pool.clone(), web3.clone(), token_address.clone(), min_block, max_block).await?;
    let mut last_block = eth.block_number().await?.as_u64();
    let mut interval = interval(Duration::from_secs(5)); // Check for new blocks every 5 seconds.
    loop {
        tokio::select! {
            _ = shutdown_rx.recv() => {
                info!("Received shutdown signal, stopping indexer...");
                break;
            }
            _ = interval.tick() => {
                info!("Starting indexing loop iteration");
                info!("Checking for new blocks...");
                let latest_block = match eth.block_number().await {
                    Ok(block) => block.as_u64(),
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
                const BATCH_SIZE: u64 = 100; // Process smaller batches for real-time indexing.
                while from_block <= to_block {
                    let batch_end = (from_block + BATCH_SIZE - 1).min(to_block);
                    let filter = FilterBuilder::default()
                        .address(vec![token_address_h160])
                        .topics(Some(vec![transfer_topic]), None, None, None)
                        .from_block(BlockNumber::Number(U64::from(from_block)))
                        .to_block(BlockNumber::Number(U64::from(batch_end)))
                        .build();
                    info!("Fetching logs from block {} to {}", from_block, batch_end);
                    let logs = match eth.logs(filter).await {
                        Ok(logs) => logs,
                        Err(e) => {
                            error!("Failed to fetch logs from {} to {}: {}", from_block, batch_end, e);
                            if e.to_string().contains("rate limit") {
                                warn!("Rate limit hit, waiting 10 seconds...");
                                sleep(Duration::from_secs(10)).await;
                            }
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
    }
    info!("Indexer stopped successfully.");
    Ok(())
}
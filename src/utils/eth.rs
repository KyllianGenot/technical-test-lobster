use web3::types::{Log, H256, U256};
use web3::Web3;
use web3::transports::Http;
use web3::Error;
use hex;

/// Connects to an Ethereum node using the given URL.
pub async fn connect_to_node(node_url: &str) -> Result<Web3<Http>, Error> {
    let transport = Http::new(node_url)?;
    Ok(Web3::new(transport))
}

/// Decodes an Ethereum log into an ERC-20 Transfer event (sender, recipient, amount).
pub fn decode_transfer_log(log: Log) -> Result<(String, String, String), String> {
    // ERC-20 Transfer event topic hash.
    let transfer_topic = H256::from_slice(
        &hex::decode("ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")
            .map_err(|e| format!("Failed to decode transfer topic: {}", e))?,
    );

    // Check if the log is an ERC-20 Transfer event.
    if log.topics.is_empty() || log.topics[0] != transfer_topic {
        return Err("Log is not an ERC-20 Transfer event".to_string());
    }

    // Ensure required topics (sender, recipient) and data (amount) are present.
    if log.topics.len() < 3 || log.data.0.is_empty() {
        return Err("Log missing required topics or data".to_string());
    }

    // Extract and format sender and recipient from topics, skipping padding.
    let sender_bytes = log.topics[1].as_bytes();
    let recipient_bytes = log.topics[2].as_bytes();
    let sender = format!("0x{}", hex::encode(&sender_bytes[12..]));
    let recipient = format!("0x{}", hex::encode(&recipient_bytes[12..]));
    let amount = U256::from_big_endian(&log.data.0).to_string();

    Ok((sender, recipient, amount))
}
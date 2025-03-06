CREATE TABLE transfers (
    id SERIAL PRIMARY KEY,
    sender TEXT NOT NULL,
    recipient TEXT NOT NULL,
    amount TEXT NOT NULL,
    block_number BIGINT NOT NULL,
    tx_hash TEXT NOT NULL
);
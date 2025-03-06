// @generated automatically by Diesel CLI.

diesel::table! {
    transfers (id) {
        id -> Int4,
        sender -> Text,
        recipient -> Text,
        amount -> Text,
        block_number -> Int8,
        tx_hash -> Text,
    }
}

use actix_web::Scope;

pub mod transfers;

pub fn eth_scope() -> Scope {
    Scope::new("/eth")
        .service(transfers::get_transfers)
}
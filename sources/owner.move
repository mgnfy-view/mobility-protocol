module mobility_protocol::owner;

public struct OWNER has drop {}

public struct AdminCap has key, store {
    id: object::UID,
}

fun init(_otw: OWNER, ctx: &mut TxContext) {
    let admin_cap = AdminCap { id: object::new(ctx) };

    transfer::public_transfer(admin_cap, ctx.sender());
}

module mobility_protocol::owner;

public struct OWNER has drop {}

public struct OwnerCap has key, store {
    id: object::UID,
}

fun init(_otw: OWNER, ctx: &mut TxContext) {
    let owner_cap = OwnerCap { id: object::new(ctx) };

    transfer::public_transfer(owner_cap, ctx.sender());
}

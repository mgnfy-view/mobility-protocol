module mobility_protocol::owner;

// ===== One time witness structs =====

public struct OWNER has drop {}

// ===== Global storage structs =====

public struct OwnerCap has key, store {
    id: object::UID,
}

// ===== Private functions =====

fun init(_otw: OWNER, ctx: &mut TxContext) {
    let owner_cap = OwnerCap { id: object::new(ctx) };

    transfer::public_transfer(owner_cap, ctx.sender());
}

// ===== Test only =====

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    let otw = OWNER {};

    init(otw, ctx);
}

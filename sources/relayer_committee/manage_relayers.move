module mobility_protocol::manage_relayers;

use mobility_protocol::errors;
use mobility_protocol::owner;
use sui::event;
use sui::table;

// ===== One time witness structs =====

public struct MANAGE_RELAYERS has drop {}

// ===== Global storage structs =====

public struct RelayerRegistry has key {
    id: object::UID,
    relayers: table::Table<address, bool>,
    relayer_count: u64,
}

// ===== Events =====

public struct RelayerSet has copy, drop {
    relayer: address,
    is_active: bool,
}

// ===== Public functions =====

public entry fun set_relayer(
    _owner_cap: &owner::OwnerCap,
    relayer_registry: &mut RelayerRegistry,
    relayer: address,
    is_active: bool,
) {
    if (relayer_registry.relayers.contains(relayer)) {
        let relayer_status = relayer_registry.relayers.borrow_mut(relayer);
        assert!(*relayer_status != is_active, errors::relayer_status_update_not_required());

        *relayer_status = is_active;
        if (is_active) {
            relayer_registry.relayer_count = relayer_registry.relayer_count + 1;
        } else {
            relayer_registry.relayer_count = relayer_registry.relayer_count - 1;
        }
    } else {
        assert!(is_active, errors::relayer_status_update_not_required());

        relayer_registry.relayers.add(relayer, is_active);
        relayer_registry.relayer_count = relayer_registry.relayer_count + 1;
    };

    event::emit(RelayerSet {
        relayer,
        is_active,
    });
}

// ===== View functions =====

public fun get_relayer_count(relayer_registry: &RelayerRegistry): u64 {
    relayer_registry.relayer_count
}

public fun is_whitelisted_relayer(relayer_registry: &RelayerRegistry, user: address): bool {
    if (
        !relayer_registry.relayers.contains(user)
            || !*relayer_registry.relayers.borrow(user)
    ) {
        false
    } else {
        true
    }
}

// ===== Private functions =====

fun init(_otw: MANAGE_RELAYERS, ctx: &mut TxContext) {
    let relayer_registry = RelayerRegistry {
        id: object::new(ctx),
        relayers: table::new(ctx),
        relayer_count: 0,
    };

    transfer::share_object(relayer_registry);
}

// ===== Test only =====

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    let otw = MANAGE_RELAYERS {};

    init(otw, ctx);
}

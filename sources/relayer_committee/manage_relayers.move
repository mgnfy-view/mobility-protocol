module mobility_protocol::manage_relayers;

use mobility_protocol::errors;
use mobility_protocol::owner;
use sui::event;
use sui::table;

public struct MANAGE_RELAYERS has drop {}

public struct RelayerRegistry has key {
    id: object::UID,
    relayers: table::Table<address, bool>,
    relayer_count: u64,
}

public struct RelayerSet has copy, drop {
    relayer: address,
    is_active: bool,
}

fun init(_otw: MANAGE_RELAYERS, ctx: &mut TxContext) {
    let relayer_registry = RelayerRegistry {
        id: object::new(ctx),
        relayers: table::new(ctx),
        relayer_count: 0,
    };

    transfer::share_object(relayer_registry);
}

public entry fun set_relayer(
    _owner_cap: &mut owner::OwnerCap,
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

public fun get_relayer_count(relayer_registry: &mut RelayerRegistry): u64 {
    relayer_registry.relayer_count
}

public fun is_whitelisted_relayer(
    relayer_registry: &mut RelayerRegistry,
    ctx: &mut TxContext,
): bool {
    if (
        !relayer_registry.relayers.contains(ctx.sender()) || !*relayer_registry.relayers.borrow(ctx.sender())
    ) {
        false
    } else {
        true
    }
}

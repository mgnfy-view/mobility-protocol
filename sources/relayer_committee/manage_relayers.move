module mobility_protocol::manage_relayers;

use mobility_protocol::errors;
use mobility_protocol::owner::AdminCap;
use sui::event;

public struct RelayerCap has key {
    id: object::UID,
    relayer: address,
    is_active: bool,
}

public struct RelayerSet has copy, drop {
    relayer: address,
    is_active: bool,
}

public entry fun add_relayer(_admin_cap: &mut AdminCap, relayer: address, ctx: &mut TxContext) {
    let relayer_cap = RelayerCap { id: object::new(ctx), relayer, is_active: true };

    event::emit(RelayerSet {
        relayer,
        is_active: true,
    });

    transfer::share_object(relayer_cap);
}

public entry fun set_relayer_status(
    _admin_cap: &mut AdminCap,
    relayer_cap: &mut RelayerCap,
    activate: bool,
) {
    let RelayerCap { id: _, relayer, is_active } = relayer_cap;

    assert!(*is_active != activate, errors::relayer_status_update_not_required());

    relayer_cap.is_active = activate;

    event::emit(RelayerSet {
        relayer: *relayer,
        is_active: relayer_cap.is_active,
    });
}

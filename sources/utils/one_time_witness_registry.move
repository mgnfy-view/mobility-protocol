module mobility_protocol::one_time_witness_registry;

use mobility_protocol::errors;
use sui::table;

public struct ONE_TIME_WITNESS_REGISTRY has drop {}

public struct OneTimeWitnessRegistry has key {
    id: object::UID,
    registry: table::Table<u16, table::Table<address, bool>>,
}

fun init(_otw: ONE_TIME_WITNESS_REGISTRY, ctx: &mut TxContext) {
    let witness_registry = OneTimeWitnessRegistry {
        id: object::new(ctx),
        registry: table::new(ctx),
    };

    transfer::share_object(witness_registry);
}

public(package) fun use_witness(
    witness_registry: &mut OneTimeWitnessRegistry,
    domain: u16,
    user: address,
) {
    let has_used_one_time_witness = get_has_user_used_domain_one_time_witness(
        witness_registry,
        domain,
        user,
    );

    assert!(!*has_used_one_time_witness, errors::already_used_one_time_witness());

    *has_used_one_time_witness = true;
}

public fun has_user_used_domain_one_time_witness(
    witness_registry: &mut OneTimeWitnessRegistry,
    domain: u16,
    user: address,
): bool {
    *get_has_user_used_domain_one_time_witness(witness_registry, domain, user)
}

fun get_has_user_used_domain_one_time_witness(
    witness_registry: &mut OneTimeWitnessRegistry,
    domain: u16,
    user: address,
): &mut bool {
    let one_time_witness_registry_for_domain = witness_registry.registry.borrow_mut(domain);
    let has_used_one_time_witness = one_time_witness_registry_for_domain.borrow_mut(user);

    has_used_one_time_witness
}

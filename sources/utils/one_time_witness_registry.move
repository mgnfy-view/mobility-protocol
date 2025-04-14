module mobility_protocol::one_time_witness_registry;

use mobility_protocol::errors;
use sui::table;

public struct ONE_TIME_WITNESS_REGISTRY has drop {}

public struct OneTimeWitnessRegistry has key {
    id: object::UID,
    registry: table::Table<u16, table::Table<u256, bool>>,
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
    key: u256,
) {
    let has_used_one_time_witness = get_has_user_used_domain_one_time_witness(
        witness_registry,
        domain,
        key,
    );

    assert!(!*has_used_one_time_witness, errors::already_used_one_time_witness());

    *has_used_one_time_witness = true;
}

public fun has_user_used_domain_one_time_witness(
    witness_registry: &mut OneTimeWitnessRegistry,
    domain: u16,
    key: u256,
): bool {
    *get_has_user_used_domain_one_time_witness(witness_registry, domain, key)
}

fun get_has_user_used_domain_one_time_witness(
    witness_registry: &mut OneTimeWitnessRegistry,
    domain: u16,
    key: u256,
): &mut bool {
    let one_time_witness_registry_for_domain = witness_registry.registry.borrow_mut(domain);
    let has_used_one_time_witness = one_time_witness_registry_for_domain.borrow_mut(key);

    has_used_one_time_witness
}

module mobility_protocol::one_time_witness_registry;

use mobility_protocol::errors;
use sui::bag;
use sui::table;

// ===== One time witness structs =====

public struct ONE_TIME_WITNESS_REGISTRY has drop {}

// ===== Global storage structs =====

public struct OneTimeWitnessRegistry has key {
    id: object::UID,
    registry: table::Table<u16, bag::Bag>,
}

// ===== View functions =====

public fun has_user_used_domain_one_time_witness<T: copy + drop + store>(
    witness_registry: &mut OneTimeWitnessRegistry,
    domain: u16,
    key: T,
): bool {
    *get_has_user_used_domain_one_time_witness(witness_registry, domain, key)
}

fun get_has_user_used_domain_one_time_witness<T: copy + drop + store>(
    witness_registry: &mut OneTimeWitnessRegistry,
    domain: u16,
    key: T,
): &mut bool {
    let one_time_witness_registry_for_domain = witness_registry.registry.borrow_mut(domain);
    let has_used_one_time_witness = one_time_witness_registry_for_domain.borrow_mut(key);

    has_used_one_time_witness
}

// ===== Package functions =====

public(package) fun use_witness<T: copy + drop + store>(
    one_time_witness_registry: &mut OneTimeWitnessRegistry,
    domain: u16,
    key: T,
) {
    let has_used_one_time_witness = get_has_user_used_domain_one_time_witness(
        one_time_witness_registry,
        domain,
        key,
    );

    assert!(!*has_used_one_time_witness, errors::already_used_one_time_witness());

    *has_used_one_time_witness = true;
}

// ===== Private functions =====

fun init(_otw: ONE_TIME_WITNESS_REGISTRY, ctx: &mut TxContext) {
    let witness_registry = OneTimeWitnessRegistry {
        id: object::new(ctx),
        registry: table::new(ctx),
    };

    transfer::share_object(witness_registry);
}

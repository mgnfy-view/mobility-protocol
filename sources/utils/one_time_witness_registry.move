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

public fun is_domain_one_time_witness_used<T: copy + drop + store>(
    one_time_witness_registry: &OneTimeWitnessRegistry,
    domain: u16,
    key: T,
): bool {
    let (is_domain_one_time_witness_used, _) = is_domain_one_time_witness_used_and_domain_exists(
        one_time_witness_registry,
        domain,
        key,
    );

    is_domain_one_time_witness_used
}

// ===== Package functions =====

public(package) fun use_witness<T: copy + drop + store>(
    one_time_witness_registry: &mut OneTimeWitnessRegistry,
    domain: u16,
    key: T,
    ctx: &mut TxContext,
) {
    let (
        is_domain_one_time_witness_used,
        domain_exists,
    ) = is_domain_one_time_witness_used_and_domain_exists(
        one_time_witness_registry,
        domain,
        key,
    );
    assert!(!is_domain_one_time_witness_used, errors::already_used_domain_one_time_witness());

    if (!domain_exists) create_domain(one_time_witness_registry, domain, ctx);
    one_time_witness_registry.registry.borrow_mut(domain).add(key, true);
}

// ===== Private functions =====

fun init(_otw: ONE_TIME_WITNESS_REGISTRY, ctx: &mut TxContext) {
    let witness_registry = OneTimeWitnessRegistry {
        id: object::new(ctx),
        registry: table::new(ctx),
    };

    transfer::share_object(witness_registry);
}

fun is_domain_one_time_witness_used_and_domain_exists<T: copy + drop + store>(
    one_time_witness_registry: &OneTimeWitnessRegistry,
    domain: u16,
    key: T,
): (bool, bool) {
    if (!one_time_witness_registry.registry.contains(domain)) {
        (false, false)
    } else {
        let one_time_witness_registry_for_domain = one_time_witness_registry
            .registry
            .borrow(domain);

        (one_time_witness_registry_for_domain.contains(key), true)
    }
}

fun create_domain(
    one_time_witness_registry: &mut OneTimeWitnessRegistry,
    domain: u16,
    ctx: &mut TxContext,
) {
    one_time_witness_registry.registry.add(domain, bag::new(ctx));
}

// ===== Test only =====

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    let otw = ONE_TIME_WITNESS_REGISTRY {};

    init(otw, ctx);
}

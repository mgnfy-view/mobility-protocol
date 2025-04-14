module mobility_protocol::create_lending_pools;

use mobility_protocol::config;
use mobility_protocol::errors;
use mobility_protocol::one_time_witness_registry;
use mobility_protocol::owner;
use sui::balance;
use sui::event;
use sui::table;

public struct CoinKey<phantom CoinType: store> has copy, drop, store {}

public struct SubLendingPoolParameters has copy, drop, store {
    lending_duration: u64,
    interest_rate_in_bps: u16,
}

public struct SubLendingPoolInfo has store {
    total_supply_coins: u64,
    total_supply_shares: u64,
    total_borrow_coins: u64,
    total_borrow_shares: u64,
}

public struct LendingPoolWrapper<phantom CoinType: store> has key {
    id: object::UID,
    balance: balance::Balance<CoinType>,
    sub_lending_pools: table::Table<SubLendingPoolParameters, SubLendingPoolInfo>,
}

public struct LendingPoolWrapperCreated<phantom CoinType: store> has copy, drop {
    id: object::ID,
    coin_key: CoinKey<CoinType>,
}

public struct SubLendingPoolCreated has copy, drop {
    lending_pool_wrapper_id: object::ID,
    sub_lending_pool_parameters: SubLendingPoolParameters,
}

public entry fun create_lending_pool_wrapper<CoinType: store>(
    _owner_cap: &mut owner::OwnerCap,
    one_time_witness_registry: &mut one_time_witness_registry::OneTimeWitnessRegistry,
    ctx: &mut TxContext,
) {
    let coin_key = CoinKey<CoinType> {};
    one_time_witness_registry::use_witness<CoinKey<CoinType>>(
        one_time_witness_registry,
        config::lending_pool_creation_domain(),
        coin_key,
    );

    let lending_pool_wrapper = LendingPoolWrapper {
        id: object::new(ctx),
        balance: balance::zero<CoinType>(),
        sub_lending_pools: table::new(ctx),
    };

    let lending_pool_wrapper_id = lending_pool_wrapper.id.to_inner();
    event::emit(LendingPoolWrapperCreated {
        id: lending_pool_wrapper_id,
        coin_key,
    });

    transfer::share_object(lending_pool_wrapper);
}

public entry fun create_sub_lending_pool<CoinType: store>(
    lending_pool_wrapper: &mut LendingPoolWrapper<CoinType>,
    lending_duration: u64,
    interest_rate_in_bps: u16,
) {
    assert!(
        lending_duration % config::lending_interval() == 0,
        errors::invalid_lending_pool_duration(),
    );
    assert!(
        interest_rate_in_bps as u64 % config::interest_rate_increment_in_bps() == 0,
        errors::invalid_interest_rate(),
    );

    let sub_lending_pool_parameters = SubLendingPoolParameters {
        lending_duration,
        interest_rate_in_bps,
    };
    assert!(
        !lending_pool_wrapper.sub_lending_pools.contains(sub_lending_pool_parameters),
        errors::sub_lending_pool_already_exists(),
    );

    let sub_lending_pool_info = SubLendingPoolInfo {
        total_supply_coins: 0,
        total_supply_shares: 0,
        total_borrow_coins: 0,
        total_borrow_shares: 0,
    };
    lending_pool_wrapper.sub_lending_pools.add(sub_lending_pool_parameters, sub_lending_pool_info);

    event::emit(SubLendingPoolCreated {
        lending_pool_wrapper_id: lending_pool_wrapper.id.to_inner(),
        sub_lending_pool_parameters,
    });
}

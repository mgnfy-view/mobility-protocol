module mobility_protocol::create_lending_pools;

use mobility_protocol::config;
use mobility_protocol::constants;
use mobility_protocol::errors;
use mobility_protocol::one_time_witness_registry;
use mobility_protocol::owner;
use mobility_protocol::utils;
use sui::balance;
use sui::clock;
use sui::coin;
use sui::event;
use sui::table;

// ===== Global storage structs =====

public struct SubLendingPoolParameters has copy, drop, store {
    lending_duration: u64,
    interest_rate_in_bps: u16,
}

public struct SubLendingPoolInfo has store {
    total_supply_coins: u64,
    total_supply_shares: u64,
    total_borrow_coins: u64,
    total_borrow_shares: u64,
    last_update_timestamp: u64,
}

public struct LendingPoolWrapper<phantom CoinType> has key {
    id: object::UID,
    balance: balance::Balance<CoinType>,
    sub_lending_pools: table::Table<SubLendingPoolParameters, SubLendingPoolInfo>,
}

public struct CoinKey<phantom CoinType> has copy, drop, store {}

// ===== Events =====

public struct LendingPoolWrapperCreated<phantom CoinType> has copy, drop {
    id: object::ID,
    coin_key: CoinKey<CoinType>,
}

public struct SubLendingPoolCreated has copy, drop {
    lending_pool_wrapper_id: object::ID,
    sub_lending_pool_parameters: SubLendingPoolParameters,
}

// ===== Public functions =====

public entry fun create_lending_pool_wrapper<CoinType>(
    _owner_cap: &owner::OwnerCap,
    one_time_witness_registry: &mut one_time_witness_registry::OneTimeWitnessRegistry,
    ctx: &mut TxContext,
) {
    let coin_key = CoinKey<CoinType> {};
    one_time_witness_registry::use_witness<CoinKey<CoinType>>(
        one_time_witness_registry,
        config::lending_pool_creation_domain(),
        coin_key,
        ctx,
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

public entry fun create_sub_lending_pool<CoinType>(
    lending_pool_wrapper: &mut LendingPoolWrapper<CoinType>,
    clock: &clock::Clock,
    lending_duration: u64,
    interest_rate_in_bps: u16,
) {
    assert!(
        lending_duration % config::lending_interval() == 0
            && lending_duration < config::max_lending_duration(),
        errors::invalid_lending_pool_duration(),
    );
    assert!(
        interest_rate_in_bps as u64 % config::interest_rate_increment_in_bps() == 0
            && interest_rate_in_bps < constants::BASIS_POINTS(),
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
        last_update_timestamp: utils::get_time_in_seconds(clock),
    };
    lending_pool_wrapper.sub_lending_pools.add(sub_lending_pool_parameters, sub_lending_pool_info);

    event::emit(SubLendingPoolCreated {
        lending_pool_wrapper_id: lending_pool_wrapper.id.to_inner(),
        sub_lending_pool_parameters,
    });
}

// ===== View functions =====

public fun get_lending_pool_balance<CoinType>(
    lending_pool_wrapper: &LendingPoolWrapper<CoinType>,
): u64 {
    lending_pool_wrapper.balance.value()
}

public fun get_sub_lending_pool_info<CoinType>(
    lending_pool_wrapper: &LendingPoolWrapper<CoinType>,
    lending_duration: u64,
    interest_rate_in_bps: u16,
): (u64, u64, u64, u64, u64) {
    let sub_lending_pool_parameters = SubLendingPoolParameters {
        lending_duration,
        interest_rate_in_bps,
    };

    let sub_lending_pool_info = lending_pool_wrapper
        .sub_lending_pools
        .borrow(sub_lending_pool_parameters);

    (
        sub_lending_pool_info.total_supply_coins,
        sub_lending_pool_info.total_supply_shares,
        sub_lending_pool_info.total_borrow_coins,
        sub_lending_pool_info.total_borrow_shares,
        sub_lending_pool_info.last_update_timestamp,
    )
}

// ===== Package functions =====

public(package) fun get_lending_pool_wrapper_id<CoinType>(
    lending_pool_wrapper: &LendingPoolWrapper<CoinType>,
): object::ID {
    let LendingPoolWrapper { id: uid, balance: _, sub_lending_pools: _ } = lending_pool_wrapper;

    uid.to_inner()
}

public(package) fun get_sub_lending_pool_parameters_object(
    lending_duration: u64,
    interest_rate_in_bps: u16,
): SubLendingPoolParameters {
    SubLendingPoolParameters {
        lending_duration,
        interest_rate_in_bps,
    }
}

public(package) fun update_sub_lending_pool_info<CoinType>(
    lending_pool_wrapper: &mut LendingPoolWrapper<CoinType>,
    clock: &clock::Clock,
    lending_duration: u64,
    interest_rate_in_bps: u16,
    total_supply_coins: u64,
    total_supply_shares: u64,
    total_borrow_coins: u64,
    total_borrow_shares: u64,
) {
    let sub_lending_pool_parameters = get_sub_lending_pool_parameters_object(
        lending_duration,
        interest_rate_in_bps,
    );
    let sub_lending_pool_info = lending_pool_wrapper
        .sub_lending_pools
        .borrow_mut(sub_lending_pool_parameters);

    sub_lending_pool_info.total_supply_coins = total_supply_coins;
    sub_lending_pool_info.total_supply_shares = total_supply_shares;
    sub_lending_pool_info.total_borrow_coins = total_borrow_coins;
    sub_lending_pool_info.total_borrow_shares = total_borrow_shares;
    sub_lending_pool_info.last_update_timestamp = utils::get_time_in_seconds(clock);
}

public(package) fun receive_coins_for_lending_pool<CoinType>(
    lending_pool_wrapper: &mut LendingPoolWrapper<CoinType>,
    receiving_coin: transfer::Receiving<sui::coin::Coin<CoinType>>,
): u64 {
    let coin = transfer::public_receive(&mut lending_pool_wrapper.id, receiving_coin);
    let amount = coin.value();
    lending_pool_wrapper.balance.join(coin::into_balance(coin));

    amount
}

public(package) fun withdraw_coins_from_lending_pool<CoinType>(
    lending_pool_wrapper: &mut LendingPoolWrapper<CoinType>,
    amount: u64,
    user: address,
    ctx: &mut TxContext,
) {
    let coin = lending_pool_wrapper.balance.split(amount).into_coin(ctx);

    transfer::public_transfer(coin, user);
}

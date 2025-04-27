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

/// The wrapper that stores all the sub lending pools. Each sub lending pool has a
/// different lending duration and interest rate.
public struct LendingPoolWrapper<phantom CoinType> has key {
    id: object::UID,
    balance: balance::Balance<CoinType>,
    ltv: u16,
    grace_period: u64,
    aggregator_id: object::ID,
    sub_lending_pools: table::Table<SubLendingPoolParameters, SubLendingPoolInfo>,
}

/// The sub lending pool properties, namely the lending duration and interest rate.
public struct SubLendingPoolParameters has copy, drop, store {
    lending_duration: u64,
    interest_rate_in_bps: u16,
}

/// Stores the total number of coins supplied and borrowed from a sub lending pool.
/// Also keeps track of shares for the same.
public struct SubLendingPoolInfo has store {
    total_supply_coins: u64,
    total_supply_shares: u64,
    total_borrow_coins: u64,
    total_borrow_shares: u64,
    last_update_timestamp: u64,
}

/// Serves as a key in the domain-wise one time witness registry to ensure that only
/// one lending pool wrapper can be created per coin.
public struct CoinKey<phantom CoinType> has copy, drop, store {}

// ===== Events =====

/// Emitted when a new lending pool wrapper is created by the owner.
public struct LendingPoolWrapperCreated<phantom CoinType> has copy, drop {
    id: object::ID,
    coin_key: CoinKey<CoinType>,
}

/// Emitted when a new sub lending pool wrapper is created.
public struct SubLendingPoolCreated has copy, drop {
    lending_pool_wrapper_id: object::ID,
    sub_lending_pool_parameters: SubLendingPoolParameters,
}

/// Emitted when the ltv of a lending pool is updated.
public struct LtvUpdated has copy, drop {
    lending_pool_wrapper_id: object::ID,
    ltv: u16,
}

/// Emitted when the grace period of a lending pool is updated.
public struct GracePeriodUpdated has copy, drop {
    lending_pool_wrapper_id: object::ID,
    grace_period: u64,
}

/// Emitted when the aggregator id of a lending pool is updated.
public struct AggregatorIdUpdated has copy, drop {
    lending_pool_wrapper_id: object::ID,
    aggregator_id: object::ID,
}

// ===== Public functions =====

/// Allows anyone to create a sub lending pool within a valid lending pool with
/// the given lending duration and interest rate.
///
/// Args:
///
/// lending_pool_wrapper:   The lending pool for the given coin.
/// clock:                  The sui clock.
/// lending_duration:       The lending duration for the sub lending pool.
/// interest_rate_in_bps:   The interest rate in bps for the sub lending pool.
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

/// Gets the lending pool info.
///
/// Args:
///
/// lending_pool_wrapper: The lending pool for the given coin.
///
/// Returns the TVL, ltv, grace period for loans, and the switchboard aggregator
/// id to be used for fetchin coin price in usd denomination.
public fun get_lending_pool_info<CoinType>(
    lending_pool_wrapper: &LendingPoolWrapper<CoinType>,
): (u64, u16, u64, object::ID) {
    (
        lending_pool_wrapper.balance.value(),
        lending_pool_wrapper.ltv,
        lending_pool_wrapper.grace_period,
        lending_pool_wrapper.aggregator_id,
    )
}

/// Gets the sub lending pool info.
///
/// Args:
///
/// lending_pool_wrapper:   The lending pool for the given coin.
/// lending_duration:       The lending duration for the sub lending pool.
/// interest_rate_in_bps:   The interest rate in bps for the sub lending pool.
///
/// Returns the supply coins and shares, and the borrow coins and shares along
/// with the last update timestamp.
public fun get_sub_lending_pool_info<CoinType>(
    lending_pool_wrapper: &LendingPoolWrapper<CoinType>,
    lending_duration: u64,
    interest_rate_in_bps: u16,
): (u64, u64, u64, u64, u64) {
    let sub_lending_pool_parameters = SubLendingPoolParameters {
        lending_duration,
        interest_rate_in_bps,
    };

    if (lending_pool_wrapper.sub_lending_pools.contains(sub_lending_pool_parameters)) {
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
    } else {
        (0, 0, 0, 0, 0)
    }
}

// ===== Admin functions =====

/// Allows the owner to create lending pool wrappers for different coins.
///
/// Args:
///
/// _owner_cap:                 The owner capability object.
/// one_time_witness_registry:  The one time witness registry.
/// ltv:                        The ltv for the lending pool.
/// grace_period:               The grace period to pay back loans.
/// aggregator_id:              The switchboard aggregator id for the coin.
/// ctx:                        The transaction context.
public entry fun create_lending_pool_wrapper<CoinType>(
    _owner_cap: &owner::OwnerCap,
    one_time_witness_registry: &mut one_time_witness_registry::OneTimeWitnessRegistry,
    ltv: u16, // should be in bps
    grace_period: u64,
    aggregator_id: object::ID,
    ctx: &mut TxContext,
) {
    let coin_key = CoinKey<CoinType> {};
    one_time_witness_registry.use_witness(
        config::lending_pool_creation_domain(),
        coin_key,
        ctx,
    );

    let lending_pool_wrapper = LendingPoolWrapper {
        id: object::new(ctx),
        balance: balance::zero<CoinType>(),
        ltv,
        grace_period,
        aggregator_id,
        sub_lending_pools: table::new(ctx),
    };

    event::emit(LendingPoolWrapperCreated {
        id: lending_pool_wrapper.id.to_inner(),
        coin_key,
    });

    transfer::share_object(lending_pool_wrapper);
}

/// Allows the owner to update the lending pool ltv.
///
/// Args:
///
/// _owner_cap:             The owner capability object.
/// lending_pool_wrapper:   The lending pool for the given coin.
/// ltv:                    The new ltv.
public entry fun update_lending_pool_ltv<CoinType>(
    _owner_cap: &owner::OwnerCap,
    lending_pool_wrapper: &mut LendingPoolWrapper<CoinType>,
    ltv: u16,
) {
    assert!(ltv < constants::BASIS_POINTS() && ltv > 0, errors::invalid_ltv());

    lending_pool_wrapper.ltv = ltv;

    event::emit(LtvUpdated {
        lending_pool_wrapper_id: lending_pool_wrapper.id.to_inner(),
        ltv,
    });
}

/// Allows the owner to update the lending pool grace period.
///
/// Args:
///
/// _owner_cap:             The owner capability object.
/// lending_pool_wrapper:   The lending pool for the given coin.
/// grace_period:           The new grace period.
public entry fun update_lending_pool_grace_period<CoinType>(
    _owner_cap: &owner::OwnerCap,
    lending_pool_wrapper: &mut LendingPoolWrapper<CoinType>,
    grace_period: u64,
) {
    lending_pool_wrapper.grace_period = grace_period;

    event::emit(GracePeriodUpdated {
        lending_pool_wrapper_id: lending_pool_wrapper.id.to_inner(),
        grace_period,
    });
}

/// Allows the owner to update the lending pool switchboard aggregator id.
///
/// Args:
///
/// _owner_cap:             The owner capability object.
/// lending_pool_wrapper:   The lending pool for the given coin.
/// aggregator_id:          The new switchboard aggregator id.
public entry fun update_lending_pool_switchboard_aggregator_id<CoinType>(
    _owner_cap: &owner::OwnerCap,
    lending_pool_wrapper: &mut LendingPoolWrapper<CoinType>,
    aggregator_id: object::ID,
) {
    lending_pool_wrapper.aggregator_id = aggregator_id;

    event::emit(AggregatorIdUpdated {
        lending_pool_wrapper_id: lending_pool_wrapper.id.to_inner(),
        aggregator_id,
    });
}

// ===== Package functions =====

/// Gets the lending pool ID.
///
/// Args:
///
/// lending_pool_wrapper: The lending pool for the given coin.
///
/// Returns the lending pool wrapper ID.
public(package) fun get_lending_pool_id<CoinType>(
    lending_pool_wrapper: &LendingPoolWrapper<CoinType>,
): object::ID {
    let LendingPoolWrapper {
        id: uid,
        balance: _,
        ltv: _,
        grace_period: _,
        aggregator_id: _,
        sub_lending_pools: _,
    } = lending_pool_wrapper;

    uid.to_inner()
}

/// Wraps lending duration and interest rate into the `SubLendingPoolParameters` object.
///
/// Args:
///
/// lending_duration:       The lending duration for the sub lending pool.
/// interest_rate_in_bps:   The interest rate in bps for the sub lending pool.
///
/// Returns the `SubLendingPoolParameters` object.
public(package) fun get_sub_lending_pool_parameters_object(
    lending_duration: u64,
    interest_rate_in_bps: u16,
): SubLendingPoolParameters {
    SubLendingPoolParameters {
        lending_duration,
        interest_rate_in_bps,
    }
}

/// Unwraps the `SubLendingPoolParameters` into lending duration and interest rate in bps.
///
/// Args:
///
/// sub_lending_pool_parameters: The sub lending pool parameters object.
///
/// Returns the lending duration and interest rate in bps for the given sub lending pool.
public(package) fun unwrap_sub_lending_pool_parameters_object(
    sub_lending_pool_parameters: SubLendingPoolParameters,
): (u64, u16) {
    let SubLendingPoolParameters {
        lending_duration,
        interest_rate_in_bps,
    } = sub_lending_pool_parameters;

    (lending_duration, interest_rate_in_bps)
}

/// Allows the friend modules to update the sub lending pool info.
///
/// Args:
///
/// lending_pool_wrapper:   The lending pool for the given coin.
/// clock:                  The sui clock.
/// lending_duration:       The lending duration for the sub lending pool.
/// interest_rate_in_bps:   The interest rate in bps for the sub lending pool.
/// total_supply_coins:     The total amount of coins supplied.
/// total_supply_shares:    The total amount of supply shares minted.
/// total_borrow_coins:     The total amount of coins borrowed.
/// total_borrow_shares:    The total amount of borrow shares minted.
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

/// Allows public receipt of coins into the lending pool wrapper from friend modules.
///
/// Args:
///
/// lending_pool_wrapper:   The lending pool for the given coin.
/// receiving_coin:         The coin to receive.
public(package) fun public_receive_coins_for_lending_pool<CoinType>(
    lending_pool_wrapper: &mut LendingPoolWrapper<CoinType>,
    receiving_coin: transfer::Receiving<coin::Coin<CoinType>>,
): u64 {
    let coin = transfer::public_receive(&mut lending_pool_wrapper.id, receiving_coin);
    let amount = coin.value();
    lending_pool_wrapper.balance.join(coin::into_balance(coin));

    amount
}

/// Allows friend modules to transfer coins to the lending pool wrapper.
///
/// Args:
///
/// lending_pool_wrapper:   The lending pool for the given coin.
/// coin:                   The coin to transfer.
public(package) fun transfer_coins_to_lending_pool<CoinType>(
    lending_pool_wrapper: &mut LendingPoolWrapper<CoinType>,
    coin: coin::Coin<CoinType>,
) {
    lending_pool_wrapper.balance.join(coin::into_balance(coin));
}

/// Allows friend modules to withdraw coins from lending pool wrapper.
///
/// Args:
///
/// lending_pool_wrapper:   The lending pool for the given coin.
/// amount:                 The amount of coins to withdraw.
/// user:                   The address to transfer the withdrawn coins to.
/// ctx:                    The transaction context.
public(package) fun withdraw_coins_from_lending_pool<CoinType>(
    lending_pool_wrapper: &mut LendingPoolWrapper<CoinType>,
    amount: u64,
    user: address,
    ctx: &mut TxContext,
) {
    let coin = lending_pool_wrapper.balance.split(amount).into_coin(ctx);

    transfer::public_transfer(coin, user);
}

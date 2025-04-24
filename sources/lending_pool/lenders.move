module mobility_protocol::lenders;

use mobility_protocol::accrue_interest;
use mobility_protocol::config;
use mobility_protocol::create_lending_pools;
use mobility_protocol::errors;
use mobility_protocol::utils;
use sui::clock;
use sui::event;

// ===== Global storage structs =====

/// Tracks the amount supplied to a sub lending pool for a given coin.
/// Stores the shares received on the supplying coins.
public struct Position has key, store {
    id: object::UID,
    lending_pool_wrapper_id: object::ID,
    sub_lending_pool_parameters: create_lending_pools::SubLendingPoolParameters,
    supply_shares: u64,
}

// ===== Events =====

/// Emitted when a position object is created for an address.
public struct PositionCreated has copy, drop {
    id: object::ID,
    lending_pool_wrapper_id: object::ID,
    sub_lending_pool_parameters: create_lending_pools::SubLendingPoolParameters,
}

/// Emitted when a user supplies coins to a sub lending pool, receiving shares
/// in return.
public struct Supplied has copy, drop {
    lending_pool_wrapper_id: object::ID,
    user: address,
    sub_lending_pool_parameters: create_lending_pools::SubLendingPoolParameters,
    amount: u64,
    shares: u64,
}

/// Emitted when a user withdraws coins from a sub lending pool, burning their shares.
public struct Withdrawn has copy, drop {
    lending_pool_wrapper_id: object::ID,
    user: address,
    sub_lending_pool_parameters: create_lending_pools::SubLendingPoolParameters,
    amount: u64,
    shares: u64,
}

// ===== Public functions =====

/// Allows anyone to create a lending position object for a given sub lending pool.
///
/// Args:
///
/// lending_pool_wrapper:   The lending pool for the given coin.
/// lending_duration:       The lending duration of the given sub lending pool.
/// interest_rate_in_bps:   The interest rate of the given sub lending pool.
/// ctx:                    The transaction context.
public entry fun create_position<CoinType>(
    lending_pool_wrapper: &mut create_lending_pools::LendingPoolWrapper<CoinType>,
    lending_duration: u64,
    interest_rate_in_bps: u16,
    ctx: &mut TxContext,
) {
    let sub_lending_pool_parameters = create_lending_pools::get_sub_lending_pool_parameters_object(
        lending_duration,
        interest_rate_in_bps,
    );
    let lending_pool_wrapper_id = lending_pool_wrapper.get_lending_pool_id();
    let position = Position {
        id: object::new(ctx),
        lending_pool_wrapper_id,
        sub_lending_pool_parameters,
        supply_shares: 0,
    };

    event::emit(PositionCreated {
        id: position.id.to_inner(),
        lending_pool_wrapper_id,
        sub_lending_pool_parameters: sub_lending_pool_parameters,
    });

    transfer::public_transfer(position, ctx.sender());
}

/// Allows a user with a valid lending position object to supply coins to a sub lending
/// pool and receive interest accruing shares in return.
///
/// Args:
///
/// lending_pool_wrapper:   The lending pool for the given coin.
/// position:               The lending position object.
/// clock:                  The sui clock.
/// lending_duration:       The lending duration of the sub lending pool to deposit into.
/// interest_rate_in_bps:   The interest rate of the sub lending pool to deposit into.
/// receiving_coin:         Coin to public receive for the deposit.
/// ctx:                    The transaction context.
public entry fun supply<CoinType>(
    lending_pool_wrapper: &mut create_lending_pools::LendingPoolWrapper<CoinType>,
    position: &mut Position,
    clock: &clock::Clock,
    lending_duration: u64,
    interest_rate_in_bps: u16,
    receiving_coin: transfer::Receiving<sui::coin::Coin<CoinType>>,
    ctx: &mut TxContext,
) {
    assert!(
        lending_pool_wrapper.get_lending_pool_id() == position.lending_pool_wrapper_id,
        errors::invalid_position(),
    );

    accrue_interest::accrue_interest(
        lending_pool_wrapper,
        clock,
        lending_duration,
        interest_rate_in_bps,
    );

    let amount = lending_pool_wrapper.public_receive_coins_for_lending_pool<CoinType>(
        receiving_coin,
    );
    assert!(amount > 0, errors::amount_zero());

    let (
        mut total_supply_coins,
        mut total_supply_shares,
        total_borrow_coins,
        total_borrow_shares,
        _,
    ) = lending_pool_wrapper.get_sub_lending_pool_info(
        lending_duration,
        interest_rate_in_bps,
    );
    let shares = utils::mul_div_u64(
        amount,
        total_supply_shares + config::virtual_shares(),
        total_supply_coins + config::virtual_coins(),
    );

    position.supply_shares = position.supply_shares + shares;
    total_supply_coins = total_supply_coins + amount;
    total_supply_shares = total_supply_shares + shares;

    lending_pool_wrapper.update_sub_lending_pool_info(
        clock,
        lending_duration,
        interest_rate_in_bps,
        total_supply_coins,
        total_supply_shares,
        total_borrow_coins,
        total_borrow_shares,
    );

    let sub_lending_pool_parameters = create_lending_pools::get_sub_lending_pool_parameters_object(
        lending_duration,
        interest_rate_in_bps,
    );
    event::emit(Supplied {
        lending_pool_wrapper_id: lending_pool_wrapper.get_lending_pool_id(),
        user: ctx.sender(),
        sub_lending_pool_parameters,
        amount,
        shares,
    });
}

/// Allows a user with a valid lending position to burn their shares and withdraw coins from a
/// sub lending pool.
///
/// Args:
///
/// lending_pool_wrapper:   The lending pool for the given coin.
/// position:               The lending position object.
/// clock:                  The sui clock.
/// amount:                 The amount of coins to withdraw.
/// lending_duration:       The lending duration of the sub lending pool to withdraw from.
/// interest_rate_in_bps:   The interest rate of the sub lending pool to withdraw from.
/// ctx:                    The transaction context.
public entry fun withdraw<CoinType>(
    lending_pool_wrapper: &mut create_lending_pools::LendingPoolWrapper<CoinType>,
    position: &mut Position,
    clock: &clock::Clock,
    amount: u64,
    lending_duration: u64,
    interest_rate_in_bps: u16,
    ctx: &mut TxContext,
) {
    assert!(amount > 0, errors::amount_zero());

    accrue_interest::accrue_interest(
        lending_pool_wrapper,
        clock,
        lending_duration,
        interest_rate_in_bps,
    );

    let (
        mut total_supply_coins,
        mut total_supply_shares,
        total_borrow_coins,
        total_borrow_shares,
        _,
    ) = lending_pool_wrapper.get_sub_lending_pool_info(
        lending_duration,
        interest_rate_in_bps,
    );
    let shares = utils::mul_div_u64(
        amount,
        total_supply_shares + config::virtual_shares(),
        total_supply_coins + config::virtual_coins(),
    );

    position.supply_shares = position.supply_shares - shares;
    total_supply_coins = total_supply_coins - amount;
    total_supply_shares = total_supply_shares - shares;

    assert!(total_supply_coins >= total_borrow_coins, errors::insufficient_liquidity());

    lending_pool_wrapper.update_sub_lending_pool_info(
        clock,
        lending_duration,
        interest_rate_in_bps,
        total_supply_coins,
        total_supply_shares,
        total_borrow_coins,
        total_borrow_shares,
    );
    lending_pool_wrapper.withdraw_coins_from_lending_pool(amount, ctx.sender(), ctx);

    let sub_lending_pool_parameters = create_lending_pools::get_sub_lending_pool_parameters_object(
        lending_duration,
        interest_rate_in_bps,
    );
    event::emit(Withdrawn {
        lending_pool_wrapper_id: lending_pool_wrapper.get_lending_pool_id(),
        user: ctx.sender(),
        sub_lending_pool_parameters,
        amount,
        shares,
    });
}

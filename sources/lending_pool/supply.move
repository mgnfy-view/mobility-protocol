module mobility_protocol::supply;

use mobility_protocol::accrue_interest;
use mobility_protocol::config;
use mobility_protocol::create_lending_pools;
use mobility_protocol::one_time_witness_registry;
use mobility_protocol::utils;
use sui::clock;
use sui::event;

// ===== Global storage structs =====

public struct Position has key, store {
    id: object::UID,
    lending_pool_wrapper_id: object::ID,
    sub_lending_pool_parameters: create_lending_pools::SubLendingPoolParameters,
    supply_shares: u64,
}

public struct PositionKey has copy, drop, store {
    lending_pool_wrapper_id: object::ID,
    user: address,
}

// ===== Events =====

public struct PositionCreated has copy, drop {
    id: object::ID,
    lending_pool_wrapper_id: object::ID,
    sub_lending_pool_parameters: create_lending_pools::SubLendingPoolParameters,
}

public struct Supplied has copy, drop {
    lending_pool_wrapper_id: object::ID,
    user: address,
    sub_lending_pool_parameters: create_lending_pools::SubLendingPoolParameters,
    amount: u64,
    shares: u64,
}

// ===== Public functions =====

public entry fun create_position<CoinType>(
    one_time_witness_registry: &mut one_time_witness_registry::OneTimeWitnessRegistry,
    lending_pool_wrapper: &mut create_lending_pools::LendingPoolWrapper<CoinType>,
    lending_duration: u64,
    interest_rate_in_bps: u16,
    ctx: &mut TxContext,
) {
    let lending_pool_wrapper_id = create_lending_pools::get_lending_pool_wrapper_id(
        lending_pool_wrapper,
    );
    let position_key = PositionKey {
        lending_pool_wrapper_id,
        user: ctx.sender(),
    };
    one_time_witness_registry::use_witness(
        one_time_witness_registry,
        config::supply_domain(),
        position_key,
        ctx,
    );

    let sub_lending_pool_parameters = create_lending_pools::get_sub_lending_pool_parameters_object(
        lending_duration,
        interest_rate_in_bps,
    );
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

public entry fun supply<CoinType>(
    lending_pool_wrapper: &mut create_lending_pools::LendingPoolWrapper<CoinType>,
    position: &mut Position,
    clock: &clock::Clock,
    lending_duration: u64,
    interest_rate_in_bps: u16,
    receiving_coin: transfer::Receiving<sui::coin::Coin<CoinType>>,
    ctx: &mut TxContext,
) {
    accrue_interest::accrue_interest(
        lending_pool_wrapper,
        clock,
        lending_duration,
        interest_rate_in_bps,
    );

    let amount = create_lending_pools::receive_coins_for_lending_pool(
        lending_pool_wrapper,
        receiving_coin,
    );

    let (
        mut total_supply_coins,
        mut total_supply_shares,
        total_borrow_coins,
        total_borrow_shares,
        _,
    ) = create_lending_pools::get_sub_lending_pool_info<CoinType>(
        lending_pool_wrapper,
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

    create_lending_pools::update_sub_lending_pool_info(
        lending_pool_wrapper,
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
        lending_pool_wrapper_id: create_lending_pools::get_lending_pool_wrapper_id(
            lending_pool_wrapper,
        ),
        user: ctx.sender(),
        sub_lending_pool_parameters,
        amount,
        shares,
    });
}

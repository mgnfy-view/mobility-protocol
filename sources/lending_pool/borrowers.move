module mobility_protocol::borrowers;

use mobility_protocol::accrue_interest;
use mobility_protocol::attest_btc_deposit;
use mobility_protocol::config;
use mobility_protocol::constants;
use mobility_protocol::create_lending_pools;
use mobility_protocol::errors;
use mobility_protocol::utils;
use sui::clock;
use sui::coin;
use sui::event;
use switchboard::aggregator::Aggregator;

// ==== Global storage structs =====

public struct BorrowPosition has key {
    id: object::UID,
    user: address,
    lending_pool_wrapper_id: object::ID,
    sub_lending_pool_parameters: create_lending_pools::SubLendingPoolParameters,
    borrow_shares: u64,
    backing_collateral_amount: u64,
    borrow_timestamp: u64,
    is_liquidated: bool,
}

// ===== Events =====

public struct Borrowed has copy, drop, store {
    user: address,
    lending_pool_wrapper_id: object::ID,
    sub_lending_pool_parameters: create_lending_pools::SubLendingPoolParameters,
    btc_collateral_required: u64,
    borrow_amount: u64,
    borrow_shares: u64,
    borrow_timestamp: u64,
}

// ===== Public functions =====

public entry fun borrow<CoinType>(
    lending_pool_wrapper: &mut create_lending_pools::LendingPoolWrapper<CoinType>,
    collateral_proof: &mut attest_btc_deposit::CollateralProof,
    btc_usd_aggregator: &Aggregator,
    borrow_coin_usd_aggregator: &Aggregator,
    borrow_coin_metadata: &coin::CoinMetadata<CoinType>,
    clock: &clock::Clock,
    lending_duration: u64,
    interest_rate_in_bps: u16,
    borrow_amount: u64,
    ctx: &mut TxContext,
) {
    let (
        user,
        btc_collateral_deposited,
        btc_collateral_used,
    ) = collateral_proof.get_collateral_proof_info();
    assert!(user == ctx.sender(), errors::not_collateral_proof_owner());
    assert!(borrow_amount > 0, errors::amount_zero());

    let btc_collateral_required = calculate_btc_collateral_required_for_borrow_amount(
        lending_pool_wrapper,
        btc_usd_aggregator,
        borrow_coin_usd_aggregator,
        borrow_coin_metadata,
        borrow_amount,
    );
    assert!(
        btc_collateral_required <= btc_collateral_deposited - btc_collateral_used,
        errors::insufficient_balance(),
    );
    collateral_proof.use_btc_collateral(btc_collateral_required);

    accrue_interest::accrue_interest(
        lending_pool_wrapper,
        clock,
        lending_duration,
        interest_rate_in_bps,
    );

    let (
        total_supply_coins,
        total_supply_shares,
        mut total_borrow_coins,
        mut total_borrow_shares,
        _,
    ) = lending_pool_wrapper.get_sub_lending_pool_info<CoinType>(
        lending_duration,
        interest_rate_in_bps,
    );
    let borrow_shares = utils::mul_div_u64(
        borrow_amount,
        total_borrow_shares + config::virtual_shares(),
        total_borrow_coins + config::virtual_coins(),
    );
    total_borrow_coins = total_borrow_coins + borrow_amount;
    total_borrow_shares = total_borrow_shares + borrow_shares;
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
    lending_pool_wrapper.withdraw_coins_from_lending_pool(borrow_amount, ctx.sender(), ctx);

    let lending_pool_wrapper_id = lending_pool_wrapper.get_lending_pool_id();
    let sub_lending_pool_parameters = create_lending_pools::get_sub_lending_pool_parameters_object(
        lending_duration,
        interest_rate_in_bps,
    );
    let borrow_timestamp = utils::get_time_in_seconds(clock);
    let borrow_position = BorrowPosition {
        id: object::new(ctx),
        user: ctx.sender(),
        lending_pool_wrapper_id,
        sub_lending_pool_parameters,
        borrow_shares,
        backing_collateral_amount: btc_collateral_required,
        borrow_timestamp: utils::get_time_in_seconds(clock),
        is_liquidated: false,
    };

    event::emit(Borrowed {
        user: ctx.sender(),
        lending_pool_wrapper_id: lending_pool_wrapper_id,
        sub_lending_pool_parameters,
        btc_collateral_required,
        borrow_amount,
        borrow_shares,
        borrow_timestamp,
    });

    transfer::share_object(borrow_position);
}

// ===== View functions =====

public fun calculate_btc_collateral_required_for_borrow_amount<CoinType>(
    lending_pool_wrapper: &create_lending_pools::LendingPoolWrapper<CoinType>,
    btc_usd_aggregator: &Aggregator,
    borrow_coin_usd_aggregator: &Aggregator,
    borrow_coin_metadata: &coin::CoinMetadata<CoinType>,
    borrow_amount: u64,
): u64 {
    let (_, ltv, _, borrow_coin_usd_aggregator_id) = lending_pool_wrapper.get_lending_pool_info();
    assert!(
        object::id_from_address(@btc_usd_switchboard_aggregator) == btc_usd_aggregator.id(),
        errors::invalid_oracle(),
    );
    assert!(
        borrow_coin_usd_aggregator_id == borrow_coin_usd_aggregator.id(),
        errors::invalid_oracle(),
    );

    if (borrow_amount == 0) return 0;

    let btc_usd_price = utils::get_price(btc_usd_aggregator);
    let borrow_coin_price = utils::get_price(borrow_coin_usd_aggregator);
    let borrow_coin_decimals = borrow_coin_metadata.get_decimals();
    let borrow_amount_value_in_usd = utils::mul_div_u128(
        borrow_amount as u128,
        borrow_coin_price,
        borrow_coin_decimals as u128,
    );
    let btc_collateral_required_in_usd = utils::mul_div_u128(
        borrow_amount_value_in_usd,
        constants::BASIS_POINTS() as u128,
        ltv as u128,
    );
    let btc_collateral_required =
        utils::mul_div_u128(
            btc_collateral_required_in_usd,
            constants::BASE_SCALING_FACTOR() as u128,
            btc_usd_price,
        ) as u64;

    btc_collateral_required
}

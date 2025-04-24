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

/// A borrow contract that allows a user to borrow a certain amount of coins
/// for a fixed duration and rate by locking their btc collateral.
public struct BorrowPosition has key {
    id: object::UID,
    user: address,
    lending_pool_wrapper_id: object::ID,
    sub_lending_pool_parameters: create_lending_pools::SubLendingPoolParameters,
    borrow_shares: u64,
    backing_collateral_amount: u64,
    borrow_timestamp: u64,
    repaid: bool,
    is_liquidated: bool,
}

// ===== Events =====

/// Emitted when a user creates a new borrow contract.
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

/// Allows users to borrow coins from a sub lending pool by locking their btc collateral
/// for a fixed duration and rate.
///
/// Args:
///
/// lending_pool_wrapper:       The lending pool for the given coin.
/// collateral_proof:           The user's collateral proof object.
/// btc_usd_aggregator:         The switchboard aggregator for btc price in usd.
/// borrow_coin_usd_aggregator: The switchboard aggregator for borrow_coin price in usd.
/// borrow_coin_metadata:       The metadata of the coin to borrow (to fetch decimals).
/// clock:                      The sui clock.
/// lending_duration:           The lending duration of the sub lending pool to borrow from.
/// interest_rate_in_bps:       The interest rate of the sub lending pool to borrow from.
/// borrow_amount:              The amount of coins to borrow.
/// ctx:                        The transaction context.
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
    let (user, _, _) = collateral_proof.get_collateral_proof_info();
    assert!(user == ctx.sender(), errors::not_collateral_proof_owner());
    assert!(borrow_amount > 0, errors::amount_zero());

    let btc_collateral_required = calculate_btc_collateral_required_for_borrow_amount(
        lending_pool_wrapper,
        btc_usd_aggregator,
        borrow_coin_usd_aggregator,
        borrow_coin_metadata,
        borrow_amount,
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
    ) = lending_pool_wrapper.get_sub_lending_pool_info(
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
        repaid: false,
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

/// Allows anyone to fully or partially repay the loan taken by a user. The btc collateral
/// is only released once the loan is fully repaid.
///
///
/// Args:
///
/// lending_pool_wrapper:       The lending pool for the given coin.
/// collateral_proof:           The user's collateral proof object.
/// borrow_position:            The borrow position to close.
/// coin:                       The coin object to use for repayment.
/// receiver:                   The recipient of the excess coins.
/// clock:                      The sui clock.
/// ctx:                        The transaction context.
public entry fun repay<CoinType>(
    lending_pool_wrapper: &mut create_lending_pools::LendingPoolWrapper<CoinType>,
    collateral_proof: &mut attest_btc_deposit::CollateralProof,
    borrow_position: &mut BorrowPosition,
    mut coin: coin::Coin<CoinType>,
    receiver: address,
    clock: &clock::Clock,
    ctx: &mut TxContext,
) {
    let BorrowPosition {
        id: _,
        user,
        lending_pool_wrapper_id,
        sub_lending_pool_parameters,
        borrow_shares,
        backing_collateral_amount,
        borrow_timestamp: _,
        repaid,
        is_liquidated,
    } = borrow_position;
    let (collateral_proof_owner, _, _) = collateral_proof.get_collateral_proof_info();
    let mut payback_amount = coin.value();
    assert!(
        *lending_pool_wrapper_id == lending_pool_wrapper.get_lending_pool_id(),
        errors::invalid_lending_pool(),
    );
    assert!(*user == collateral_proof_owner, errors::not_collateral_proof_owner());
    assert!(!*repaid, errors::already_repaid());
    assert!(!*is_liquidated, errors::already_liquidated());
    assert!(payback_amount > 0, errors::amount_zero());

    let (
        lending_duration,
        interest_rate_in_bps,
    ) = create_lending_pools::unwrap_sub_lending_pool_parameters_object(
        *sub_lending_pool_parameters,
    );

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
    ) = lending_pool_wrapper.get_sub_lending_pool_info(
        lending_duration,
        interest_rate_in_bps,
    );
    let mut payback_shares = utils::mul_div_u64(
        payback_amount,
        total_borrow_shares + config::virtual_shares(),
        total_borrow_coins + config::virtual_coins(),
    );
    if (payback_shares > *borrow_shares) {
        payback_shares = *borrow_shares;

        payback_amount =
            utils::mul_div_u64(
                *borrow_shares,
                total_borrow_coins + config::virtual_coins(),
                total_borrow_shares + config::virtual_shares(),
            );
    };
    let split_coin = coin.split(payback_amount, ctx);

    total_borrow_coins = total_borrow_coins - payback_amount;
    total_borrow_shares = total_borrow_shares - payback_shares;
    lending_pool_wrapper.update_sub_lending_pool_info(
        clock,
        lending_duration,
        interest_rate_in_bps,
        total_supply_coins,
        total_supply_shares,
        total_borrow_coins,
        total_borrow_shares,
    );
    lending_pool_wrapper.transfer_coins_to_lending_pool(split_coin);

    borrow_position.borrow_shares = borrow_position.borrow_shares - payback_shares;
    if (borrow_position.borrow_shares == 0) {
        borrow_position.repaid = true;
        collateral_proof.credit_btc_collateral(*backing_collateral_amount);
    };

    transfer::public_transfer(coin, receiver);
}

/// Allows anyone to liquidate a borrow position once the lending duration and the grace period
/// has ended. If the usd value of the backing btc collateral is less than the amount to repay,
/// the loss is distributed among lenders. Otherwise, the liquidator keeps the entirety of the
/// borrower's btc collateral.
///
/// Args:
///
/// lending_pool_wrapper:           The lending pool for the given coin.
/// liquidator_collateral_proof:    The liquidator's collateral proof object.
/// borrow_position:                The borrow position to liquidate.
/// btc_usd_aggregator:             The switchboard aggregator for btc price in usd.
/// borrow_coin_usd_aggregator:     The switchboard aggregator for borrow_coin price in usd.
/// borrow_coin_metadata:           The metadata of the coin borrowed (to fetch decimals).
/// coin:                           The coin object to repay the debt with.
/// receiver:                       Receiver of the excess coins.
/// clock:                          The sui clock.
/// ctx:                            The transaction context.
public entry fun liquidate<CoinType>(
    lending_pool_wrapper: &mut create_lending_pools::LendingPoolWrapper<CoinType>,
    liquidator_collateral_proof: &mut attest_btc_deposit::CollateralProof,
    borrow_position: &mut BorrowPosition,
    btc_usd_aggregator: &Aggregator,
    borrow_coin_usd_aggregator: &Aggregator,
    borrow_coin_metadata: &coin::CoinMetadata<CoinType>,
    mut coin: coin::Coin<CoinType>,
    receiver: address,
    clock: &clock::Clock,
    ctx: &mut TxContext,
) {
    let BorrowPosition {
        id: _,
        user: _,
        lending_pool_wrapper_id,
        sub_lending_pool_parameters,
        borrow_shares,
        backing_collateral_amount,
        borrow_timestamp,
        repaid,
        is_liquidated,
    } = borrow_position;
    let (lending_duration, _) = create_lending_pools::unwrap_sub_lending_pool_parameters_object(
        *sub_lending_pool_parameters,
    );
    let (
        _,
        _,
        grace_period,
        borrow_coin_usd_aggregator_id,
    ) = lending_pool_wrapper.get_lending_pool_info();
    assert!(
        *lending_pool_wrapper_id == lending_pool_wrapper.get_lending_pool_id(),
        errors::invalid_lending_pool(),
    );
    assert!(
        object::id_from_address(@btc_usd_switchboard_aggregator) == btc_usd_aggregator.id(),
        errors::invalid_oracle(),
    );
    assert!(
        borrow_coin_usd_aggregator_id == borrow_coin_usd_aggregator.id(),
        errors::invalid_oracle(),
    );
    assert!(
        utils::get_time_in_seconds(clock) - *borrow_timestamp > lending_duration + grace_period,
    );
    assert!(!*repaid, errors::already_repaid());
    assert!(!*is_liquidated, errors::already_liquidated());

    let (
        lending_duration,
        interest_rate_in_bps,
    ) = create_lending_pools::unwrap_sub_lending_pool_parameters_object(
        *sub_lending_pool_parameters,
    );

    accrue_interest::accrue_interest(
        lending_pool_wrapper,
        clock,
        lending_duration,
        interest_rate_in_bps,
    );

    let (
        mut total_supply_coins,
        total_supply_shares,
        mut total_borrow_coins,
        mut total_borrow_shares,
        _,
    ) = lending_pool_wrapper.get_sub_lending_pool_info(
        lending_duration,
        interest_rate_in_bps,
    );
    let btc_usd_price = utils::get_price(btc_usd_aggregator);
    let borrow_coin_price = utils::get_price(borrow_coin_usd_aggregator);
    let backing_collateral_value_in_usd = utils::mul_div_u128(
        *backing_collateral_amount as u128,
        btc_usd_price,
        constants::BASE_SCALING_FACTOR() as u128,
    );
    let payback_amount = utils::mul_div_u64(
        *borrow_shares,
        total_borrow_coins + config::virtual_coins(),
        total_borrow_shares + config::virtual_shares(),
    );
    let payback_amount_in_usd = utils::mul_div_u128(
        payback_amount as u128,
        borrow_coin_price,
        borrow_coin_metadata.get_decimals() as u128,
    );

    let mut actual_payback_amount = payback_amount;
    let mut actual_payback_shares = *borrow_shares;
    if (backing_collateral_value_in_usd >= payback_amount_in_usd) {
        total_borrow_shares = total_borrow_shares - *borrow_shares;
        total_borrow_coins = total_borrow_coins - payback_amount;
    } else {
        actual_payback_amount =
            utils::mul_div_u128(
                backing_collateral_value_in_usd,
                borrow_coin_metadata.get_decimals() as u128,
                borrow_coin_price,
            ) as u64;
        actual_payback_shares =
            utils::mul_div_u64(
                actual_payback_amount,
                total_borrow_shares + config::virtual_shares(),
                total_borrow_coins + config::virtual_coins(),
            );

        total_borrow_shares = total_borrow_shares - *borrow_shares;
        total_borrow_coins = total_borrow_coins - payback_amount;
        total_supply_coins = total_supply_coins - (payback_amount - actual_payback_amount);
    };

    let split_coin = coin.split(actual_payback_amount, ctx);
    lending_pool_wrapper.update_sub_lending_pool_info(
        clock,
        lending_duration,
        interest_rate_in_bps,
        total_supply_coins,
        total_supply_shares,
        total_borrow_coins,
        total_borrow_shares,
    );
    lending_pool_wrapper.transfer_coins_to_lending_pool(split_coin);

    borrow_position.borrow_shares = borrow_position.borrow_shares - actual_payback_shares;
    borrow_position.repaid = true;
    borrow_position.is_liquidated = true;
    liquidator_collateral_proof.credit_btc_collateral(*backing_collateral_amount);

    transfer::public_transfer(coin, receiver);
}

// ===== View functions =====

/// Gets a borrow position's details.
///
/// Args:
///
/// borrow_position: The borrow contract.
///
/// Returns the borrower's address, lending pool ID, sub lending pool parameters,
/// borrow shares, btc collateral locked, the timestamp when the borrow was made,
/// and two boolenas indicating whether the position was repaid or liquidated.
public fun get_borrow_position_info(
    borrow_position: &BorrowPosition,
): (
    address,
    object::ID,
    create_lending_pools::SubLendingPoolParameters,
    u64,
    u64,
    u64,
    bool,
    bool,
) {
    let BorrowPosition {
        id: _,
        user,
        lending_pool_wrapper_id,
        sub_lending_pool_parameters,
        borrow_shares,
        backing_collateral_amount,
        borrow_timestamp,
        repaid,
        is_liquidated,
    } = borrow_position;

    (
        *user,
        *lending_pool_wrapper_id,
        *sub_lending_pool_parameters,
        *borrow_shares,
        *backing_collateral_amount,
        *borrow_timestamp,
        *repaid,
        *is_liquidated,
    )
}

/// Calculates the amount of btc to lock up as collateral for the given coin amount to
/// borrow.
///
/// Args:
///
/// lending_pool_wrapper:       The lending pool for the given coin.
/// btc_usd_aggregator:         The switchboard aggregator for btc price in usd.
/// borrow_coin_usd_aggregator: The switchboard aggregator for borrow_coin price in usd.
/// borrow_coin_metadata:       The metadata of the coin to borrow (to fetch decimals).
/// borrow_amount:              The amount of coins to borrow.
///
/// Returns the btc collateral to lock (scaled by 1e9, the base scaling factor).
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

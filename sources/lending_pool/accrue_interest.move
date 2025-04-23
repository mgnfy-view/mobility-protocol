module mobility_protocol::accrue_interest;

use mobility_protocol::constants;
use mobility_protocol::create_lending_pools;
use mobility_protocol::utils;
use sui::clock;
use sui::event;

// ===== Events =====

public struct InterestAccrued has copy, drop {
    lending_pool_wrapper_id: object::ID,
    sub_lending_pool_parameters: create_lending_pools::SubLendingPoolParameters,
    interest: u64,
    update_timestamp: u64,
}

// ===== Public functions =====

public entry fun accrue_interest<CoinType>(
    lending_pool_wrapper: &mut create_lending_pools::LendingPoolWrapper<CoinType>,
    clock: &clock::Clock,
    lending_duration: u64,
    interest_rate_in_bps: u16,
) {
    let (
        mut total_supply_coins,
        total_supply_shares,
        mut total_borrow_coins,
        total_borrow_shares,
        last_update_timestamp,
    ) = lending_pool_wrapper.get_sub_lending_pool_info(
        lending_duration,
        interest_rate_in_bps,
    );

    let current_timestamp = utils::get_time_in_seconds(clock);
    let elapsed_time = current_timestamp - last_update_timestamp;
    if (elapsed_time == 0) return;

    let interest =
        utils::mul_div_u128(
            total_borrow_coins as u128,
            utils::get_taylor_compounded(interest_rate_in_bps, elapsed_time),
            constants::COMPOUND_INTEREST_SCALING_FACTOR() as u128,
        ) as u64;
    total_supply_coins = total_supply_coins + interest;
    total_borrow_coins = total_borrow_coins + interest;
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
    event::emit(InterestAccrued {
        lending_pool_wrapper_id: create_lending_pools::get_lending_pool_id(
            lending_pool_wrapper,
        ),
        sub_lending_pool_parameters,
        interest,
        update_timestamp: current_timestamp,
    });
}

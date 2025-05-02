#[test_only]
module mobility_protocol::lender_tests;

use mobility_protocol::config;
use mobility_protocol::create_lending_pools;
use mobility_protocol::lenders;
use mobility_protocol::test_base;
use mobility_protocol::utils;
use sui::coin;
use sui::sui::SUI;
use sui::test_scenario as ts;
use sui::test_utils as tu;

#[test]
public fun can_create_supply_position() {
    let global_state = test_base::setup(false, false, true, false, true);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);
    let (
        lending_duration,
        interest_rate_in_bps,
    ) = test_base::get_sample_sub_lending_pool_parameters();

    {
        let lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();
        let position = scenario.take_from_sender<lenders::Position>();

        let (
            lending_pool_wrapper_id,
            actual_lending_duration,
            actual_interest_rate_in_bps,
            supply_shares,
        ) = position.get_position_info();

        tu::assert_eq(lending_pool_wrapper_id, lending_pool_wrapper.get_lending_pool_id());
        tu::assert_eq(actual_lending_duration, lending_duration);
        tu::assert_eq(actual_interest_rate_in_bps, interest_rate_in_bps);
        tu::assert_eq(supply_shares, 0);

        ts::return_shared(lending_pool_wrapper);
        scenario.return_to_sender(position);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun can_create_multiple_supply_positions_for_the_same_sub_lending_pool() {
    let global_state = test_base::setup(false, false, true, false, true);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (
        lending_duration,
        interest_rate_in_bps,
    ) = test_base::get_sample_sub_lending_pool_parameters();

    {
        test_base::create_sub_lending_pool_positions<SUI>(
            &mut scenario,
            lending_duration,
            interest_rate_in_bps,
        );
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun cannot_create_a_supply_position_for_invalid_sub_lending_pool() {
    let global_state = test_base::setup(false, false, true, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (
        lending_duration,
        interest_rate_in_bps,
    ) = test_base::get_sample_sub_lending_pool_parameters();

    {
        test_base::create_sub_lending_pool_positions<SUI>(
            &mut scenario,
            lending_duration + 1,
            interest_rate_in_bps + 1,
        );
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun can_transfer_a_lending_position_to_another_user() {
    let global_state = test_base::setup(false, false, true, false, true);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);
    let id: object::ID;

    {
        let lending_position = scenario.take_from_sender<lenders::Position>();
        (id, _, _, _) = lending_position.get_position_info();

        transfer::public_transfer(lending_position, test_base::USER_2());
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_2(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let lending_position = scenario.take_from_sender<lenders::Position>();
        let (actual_id, _, _, _) = lending_position.get_position_info();

        tu::assert_eq(id, actual_id);

        scenario.return_to_sender(lending_position);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun can_supply_to_sub_lending_pool_and_receive_shares() {
    let global_state = test_base::setup(false, false, true, true, true);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (
        lending_duration,
        interest_rate_in_bps,
    ) = test_base::get_sample_sub_lending_pool_parameters();
    let supply_amount = 1_000_000_000;

    {
        test_base::supply<SUI>(
            &mut scenario,
            &clock,
            lending_duration,
            interest_rate_in_bps,
            supply_amount,
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();
        let (balance, _, _, _) = lending_pool_wrapper.get_lending_pool_info();
        let position = scenario.take_from_sender<lenders::Position>();
        let (_, _, _, shares) = position.get_position_info();

        let expected_shares = utils::mul_div_u64(
            supply_amount,
            config::virtual_shares(),
            config::virtual_coins(),
        );

        tu::assert_eq(shares, expected_shares);
        tu::assert_eq(balance, supply_amount);

        ts::return_shared(lending_pool_wrapper);
        scenario.return_to_sender(position);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun multiple_users_can_supply_to_sub_lending_pool_and_receive_proportionate_shares() {
    let global_state = test_base::setup(false, false, true, true, true);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (
        lending_duration,
        interest_rate_in_bps,
    ) = test_base::get_sample_sub_lending_pool_parameters();
    let supply_amount = 1_000_000_000;

    {
        test_base::supply<SUI>(
            &mut scenario,
            &clock,
            lending_duration,
            interest_rate_in_bps,
            supply_amount,
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_2(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::supply<SUI>(
            &mut scenario,
            &clock,
            lending_duration,
            interest_rate_in_bps,
            supply_amount,
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();
        let (balance, _, _, _) = lending_pool_wrapper.get_lending_pool_info();
        let user1_position = scenario.take_from_sender<lenders::Position>();
        let (_, _, _, user1_shares) = user1_position.get_position_info();
        let user2_position = scenario.take_from_address<lenders::Position>(test_base::USER_2());
        let (_, _, _, user2_shares) = user2_position.get_position_info();

        let expected_shares = utils::mul_div_u64(
            supply_amount,
            config::virtual_shares(),
            config::virtual_coins(),
        );

        tu::assert_eq(user1_shares, expected_shares);
        tu::assert_eq(user2_shares, expected_shares);
        tu::assert_eq(balance, supply_amount * 2);

        ts::return_shared(lending_pool_wrapper);
        scenario.return_to_sender(user1_position);
        ts::return_to_address(test_base::USER_2(), user2_position);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun can_withdraw_from_sub_lending_pool_and_burn_shares() {
    let global_state = test_base::setup(false, false, true, true, true);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (
        lending_duration,
        interest_rate_in_bps,
    ) = test_base::get_sample_sub_lending_pool_parameters();
    let supply_amount = 1_000_000_000;

    {
        test_base::supply<SUI>(
            &mut scenario,
            &clock,
            lending_duration,
            interest_rate_in_bps,
            supply_amount,
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::withdraw<SUI>(
            &mut scenario,
            &clock,
            lending_duration,
            interest_rate_in_bps,
            supply_amount,
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();
        let (balance, _, _, _) = lending_pool_wrapper.get_lending_pool_info();
        let position = scenario.take_from_sender<lenders::Position>();
        let (_, _, _, shares) = position.get_position_info();

        tu::assert_eq(shares, 0);
        tu::assert_eq(balance, 0);

        ts::return_shared(lending_pool_wrapper);
        scenario.return_to_sender(position);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun multiple_users_can_withdraw_from_sub_lending_pool_and_burn_shares() {
    let global_state = test_base::setup(false, false, true, true, true);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (
        lending_duration,
        interest_rate_in_bps,
    ) = test_base::get_sample_sub_lending_pool_parameters();
    let supply_amount = 1_000_000_000;

    {
        test_base::supply<SUI>(
            &mut scenario,
            &clock,
            lending_duration,
            interest_rate_in_bps,
            supply_amount,
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_2(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::supply<SUI>(
            &mut scenario,
            &clock,
            lending_duration,
            interest_rate_in_bps,
            supply_amount,
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::withdraw<SUI>(
            &mut scenario,
            &clock,
            lending_duration,
            interest_rate_in_bps,
            supply_amount,
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_2(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::withdraw<SUI>(
            &mut scenario,
            &clock,
            lending_duration,
            interest_rate_in_bps,
            supply_amount,
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();
        let (balance, _, _, _) = lending_pool_wrapper.get_lending_pool_info();
        let user1_position = scenario.take_from_sender<lenders::Position>();
        let (_, _, _, user1_shares) = user1_position.get_position_info();
        let user2_position = scenario.take_from_address<lenders::Position>(test_base::USER_2());
        let (_, _, _, user2_shares) = user2_position.get_position_info();
        let user1_coin = scenario.take_from_sender<coin::Coin<SUI>>();
        let user2_coin = scenario.take_from_address<coin::Coin<SUI>>(test_base::USER_2());

        tu::assert_eq(user1_shares, 0);
        tu::assert_eq(user2_shares, 0);
        tu::assert_eq(balance, 0);

        tu::assert_eq(user1_coin.value(), supply_amount);
        tu::assert_eq(user2_coin.value(), supply_amount);

        ts::return_shared(lending_pool_wrapper);
        scenario.return_to_sender(user1_position);
        ts::return_to_address(test_base::USER_2(), user2_position);
        scenario.return_to_sender(user1_coin);
        ts::return_to_address(test_base::USER_2(), user2_coin);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun user_can_withdraw_partial_funds() {
    let global_state = test_base::setup(false, false, true, true, true);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (
        lending_duration,
        interest_rate_in_bps,
    ) = test_base::get_sample_sub_lending_pool_parameters();
    let supply_amount = 1_000_000_000;

    {
        test_base::supply<SUI>(
            &mut scenario,
            &clock,
            lending_duration,
            interest_rate_in_bps,
            supply_amount,
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::withdraw<SUI>(
            &mut scenario,
            &clock,
            lending_duration,
            interest_rate_in_bps,
            supply_amount / 2,
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();
        let (balance, _, _, _) = lending_pool_wrapper.get_lending_pool_info();
        let position = scenario.take_from_sender<lenders::Position>();
        let (_, _, _, shares) = position.get_position_info();

        let expected_shares =
            utils::mul_div_u64(
            supply_amount,
            config::virtual_shares(),
            config::virtual_coins(),
        ) / 2;

        tu::assert_eq(shares, expected_shares);
        tu::assert_eq(balance, supply_amount / 2);

        ts::return_shared(lending_pool_wrapper);
        scenario.return_to_sender(position);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

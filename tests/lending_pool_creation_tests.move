#[test_only]
module mobility_protocol::lending_pool_creation_tests;

use mobility_protocol::create_lending_pools;
use mobility_protocol::test_base;
use mobility_protocol::utils;
use sui::sui::SUI;
use sui::test_scenario as ts;
use sui::test_utils as tu;

#[test, expected_failure]
public fun non_owner_cannot_create_lending_pool_wrapper() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::create_lending_pool_wrapper<SUI>(&mut scenario);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun owner_can_create_lending_pool_wrapper() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::create_lending_pool_wrapper<SUI>(&mut scenario);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();

        tu::assert_eq(create_lending_pools::get_lending_pool_balance(&lending_pool_wrapper), 0);

        ts::return_shared(lending_pool_wrapper);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun owner_cannot_create_same_lending_pool_wrapper_twice() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::create_lending_pool_wrapper<SUI>(&mut scenario);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::create_lending_pool_wrapper<SUI>(&mut scenario);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun anyone_can_create_sub_lending_pool() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::create_lending_pool_wrapper<SUI>(&mut scenario);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (lending_duration, interest_rate_in_bps) = get_sample_sub_lending_pool_parameters();

    {
        test_base::create_sub_lending_pool<SUI>(
            &mut scenario,
            lending_duration,
            interest_rate_in_bps,
            &clock,
        )
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();

        let (
            total_supply_coins,
            total_supply_shares,
            total_borrow_coins,
            total_borrow_shares,
            last_update_timestamp,
        ) = create_lending_pools::get_sub_lending_pool_info(
            &lending_pool_wrapper,
            lending_duration,
            interest_rate_in_bps,
        );

        tu::assert_eq(total_supply_coins, 0);
        tu::assert_eq(total_supply_shares, 0);
        tu::assert_eq(total_borrow_coins, 0);
        tu::assert_eq(total_borrow_shares, 0);
        tu::assert_eq(last_update_timestamp, utils::get_time_in_seconds(&clock));

        ts::return_shared(lending_pool_wrapper);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun cannot_create_same_sub_lending_pool() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::create_lending_pool_wrapper<SUI>(&mut scenario);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (lending_duration, interest_rate_in_bps) = get_sample_sub_lending_pool_parameters();

    {
        test_base::create_sub_lending_pool<SUI>(
            &mut scenario,
            lending_duration,
            interest_rate_in_bps,
            &clock,
        )
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::create_sub_lending_pool<SUI>(
            &mut scenario,
            lending_duration,
            interest_rate_in_bps,
            &clock,
        )
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun cannot_create_sub_lending_pool_with_incorrect_parameters() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::create_lending_pool_wrapper<SUI>(&mut scenario);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (lending_duration, interest_rate_in_bps) = get_sample_sub_lending_pool_parameters();

    {
        test_base::create_sub_lending_pool<SUI>(
            &mut scenario,
            lending_duration + 1,
            interest_rate_in_bps + 1,
            &clock,
        )
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

fun get_sample_sub_lending_pool_parameters(): (u64, u16) {
    let lending_duration = 86_400;
    let interest_rate_in_bps = 1_000;

    (lending_duration, interest_rate_in_bps)
}

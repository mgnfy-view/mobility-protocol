#[test_only]
module mobility_protocol::lending_pool_creation_tests;

use mobility_protocol::create_lending_pools;
use mobility_protocol::owner;
use mobility_protocol::test_base;
use mobility_protocol::utils;
use sui::sui::SUI;
use sui::test_scenario as ts;
use sui::test_utils as tu;

#[test, expected_failure]
public fun non_owner_cannot_create_lending_pool() {
    let global_state = test_base::setup(false, false, false, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (ltv, grace_period, aggregator_id) = test_base::get_sample_lending_pool_parameters();

    {
        test_base::create_lending_pool_wrapper<SUI>(
            &mut scenario,
            ltv,
            grace_period,
            aggregator_id,
        );
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun owner_can_create_lending_pool() {
    let global_state = test_base::setup(false, false, true, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);
    let (ltv, grace_period, aggregator_id) = test_base::get_sample_lending_pool_parameters();

    {
        let lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();
        let (
            balance,
            actual_ltv,
            actual_grace_period,
            actual_aggregator_id,
        ) = create_lending_pools::get_lending_pool_info(&lending_pool_wrapper);

        tu::assert_eq(balance, 0);
        tu::assert_eq(actual_ltv, ltv);
        tu::assert_eq(actual_grace_period, grace_period);
        tu::assert_eq(actual_aggregator_id, aggregator_id);

        ts::return_shared(lending_pool_wrapper);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun owner_cannot_create_same_lending_pool_twice() {
    let global_state = test_base::setup(false, false, true, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (ltv, grace_period, aggregator_id) = test_base::get_sample_lending_pool_parameters();

    {
        test_base::create_lending_pool_wrapper<SUI>(
            &mut scenario,
            ltv,
            grace_period,
            aggregator_id,
        );
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun owner_can_update_ltv() {
    let global_state = test_base::setup(false, false, true, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);
    let new_ltv = 7_000;

    {
        let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
        let mut lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();

        create_lending_pools::update_lending_pool_ltv(
            &owner_cap,
            &mut lending_pool_wrapper,
            new_ltv,
        );

        scenario.return_to_sender(owner_cap);
        ts::return_shared(lending_pool_wrapper);
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

        let (_, actual_ltv, _, _) = lending_pool_wrapper.get_lending_pool_info();
        tu::assert_eq(actual_ltv, new_ltv);

        ts::return_shared(lending_pool_wrapper);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun owner_can_update_grace_period() {
    let global_state = test_base::setup(false, false, true, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);
    let new_grace_period = 45_200;

    {
        let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
        let mut lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();

        create_lending_pools::update_lending_pool_grace_period(
            &owner_cap,
            &mut lending_pool_wrapper,
            new_grace_period,
        );

        scenario.return_to_sender(owner_cap);
        ts::return_shared(lending_pool_wrapper);
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

        let (_, _, actual_grace_period, _) = lending_pool_wrapper.get_lending_pool_info();

        tu::assert_eq(actual_grace_period, new_grace_period);

        ts::return_shared(lending_pool_wrapper);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun owner_can_update_aggregator_id() {
    let global_state = test_base::setup(false, false, true, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
        let mut lending_pool_wrapper = scenario.take_shared<
            create_lending_pools::LendingPoolWrapper<SUI>,
        >();

        create_lending_pools::update_lending_pool_switchboard_aggregator_id(
            &owner_cap,
            &mut lending_pool_wrapper,
            object::id_from_address(@btc_usd_switchboard_aggregator),
        );

        scenario.return_to_sender(owner_cap);
        ts::return_shared(lending_pool_wrapper);
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

        let (_, _, _, aggregator_id) = lending_pool_wrapper.get_lending_pool_info();

        tu::assert_eq(aggregator_id, object::id_from_address(@btc_usd_switchboard_aggregator));

        ts::return_shared(lending_pool_wrapper);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun anyone_can_create_sub_lending_pool() {
    let global_state = test_base::setup(false, false, true, true, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
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
public fun cannot_create_same_sub_lending_pool_twice() {
    let global_state = test_base::setup(false, false, true, true, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (
        lending_duration,
        interest_rate_in_bps,
    ) = test_base::get_sample_sub_lending_pool_parameters();

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
    let global_state = test_base::setup(false, true, false, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (
        lending_duration,
        interest_rate_in_bps,
    ) = test_base::get_sample_sub_lending_pool_parameters();

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

#[test_only]
module mobility_protocol::relayer_tests;

use mobility_protocol::manage_relayers;
use mobility_protocol::owner;
use mobility_protocol::test_base;
use sui::test_scenario as ts;
use sui::test_utils;

#[test]
public fun relayer_registry_object_created_successfully() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(global_state, test_base::OWNER());
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

        test_utils::assert_eq(manage_relayers::get_relayer_count(&relayer_registry), 0);

        ts::return_shared(relayer_registry);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun relayer_can_be_set() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(global_state, test_base::OWNER());
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        set_relayer(&scenario, test_base::USER_1(), true);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

        test_utils::assert_eq(manage_relayers::get_relayer_count(&relayer_registry), 1);
        test_utils::assert_eq(
            manage_relayers::is_whitelisted_relayer(&relayer_registry, test_base::USER_1()),
            true,
        );

        ts::return_shared(relayer_registry);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun multiple_relayers_can_be_set() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(global_state, test_base::OWNER());
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        set_relayer(&scenario, test_base::USER_1(), true);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        set_relayer(&scenario, test_base::USER_2(), true);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

        test_utils::assert_eq(manage_relayers::get_relayer_count(&relayer_registry), 2);
        test_utils::assert_eq(
            manage_relayers::is_whitelisted_relayer(&relayer_registry, test_base::USER_1()),
            true,
        );
        test_utils::assert_eq(
            manage_relayers::is_whitelisted_relayer(&relayer_registry, test_base::USER_2()),
            true,
        );

        ts::return_shared(relayer_registry);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun relayer_can_be_removed() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(global_state, test_base::OWNER());
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        set_relayer(&scenario, test_base::USER_1(), true);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        set_relayer(&scenario, test_base::USER_1(), false);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

        test_utils::assert_eq(manage_relayers::get_relayer_count(&relayer_registry), 0);
        test_utils::assert_eq(
            manage_relayers::is_whitelisted_relayer(&relayer_registry, test_base::USER_1()),
            false,
        );

        ts::return_shared(relayer_registry);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun multiple_relayers_can_be_removed() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(global_state, test_base::OWNER());
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        set_relayer(&scenario, test_base::USER_1(), true);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        set_relayer(&scenario, test_base::USER_2(), true);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        set_relayer(&scenario, test_base::USER_1(), false);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        set_relayer(&scenario, test_base::USER_2(), false);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

        test_utils::assert_eq(manage_relayers::get_relayer_count(&relayer_registry), 0);
        test_utils::assert_eq(
            manage_relayers::is_whitelisted_relayer(&relayer_registry, test_base::USER_1()),
            false,
        );
        test_utils::assert_eq(
            manage_relayers::is_whitelisted_relayer(&relayer_registry, test_base::USER_2()),
            false,
        );

        ts::return_shared(relayer_registry);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

fun set_relayer(scenario: &ts::Scenario, user: address, is_active: bool) {
    let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
    let mut relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

    manage_relayers::set_relayer(&owner_cap, &mut relayer_registry, user, is_active);

    scenario.return_to_sender(owner_cap);
    ts::return_shared(relayer_registry);
}

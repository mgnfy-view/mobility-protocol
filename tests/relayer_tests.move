#[test_only]
module mobility_protocol::relayer_tests;

use mobility_protocol::manage_relayers;
use mobility_protocol::test_base;
use sui::test_scenario as ts;
use sui::test_utils as tu;

#[test]
public fun creating_relayer_registry_object_succeeds() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(global_state, test_base::OWNER());
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

        tu::assert_eq(manage_relayers::get_relayer_count(&relayer_registry), 0);

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
        test_base::set_relayers(&scenario, vector[test_base::USER_1()], vector[true]);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

        tu::assert_eq(manage_relayers::get_relayer_count(&relayer_registry), 1);
        tu::assert_eq(
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
        test_base::set_relayers(
            &scenario,
            vector[test_base::USER_1(), test_base::USER_2()],
            vector[true, true],
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

        tu::assert_eq(manage_relayers::get_relayer_count(&relayer_registry), 2);
        tu::assert_eq(
            manage_relayers::is_whitelisted_relayer(&relayer_registry, test_base::USER_1()),
            true,
        );
        tu::assert_eq(
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
        test_base::set_relayers(
            &scenario,
            vector[test_base::USER_1()],
            vector[true],
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::set_relayers(
            &scenario,
            vector[test_base::USER_1()],
            vector[false],
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

        tu::assert_eq(manage_relayers::get_relayer_count(&relayer_registry), 0);
        tu::assert_eq(
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
        test_base::set_relayers(
            &scenario,
            vector[test_base::USER_1(), test_base::USER_2()],
            vector[true, true],
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::OWNER(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::set_relayers(
            &scenario,
            vector[test_base::USER_1(), test_base::USER_2()],
            vector[false, false],
        );
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

        tu::assert_eq(manage_relayers::get_relayer_count(&relayer_registry), 0);
        tu::assert_eq(
            manage_relayers::is_whitelisted_relayer(&relayer_registry, test_base::USER_1()),
            false,
        );
        tu::assert_eq(
            manage_relayers::is_whitelisted_relayer(&relayer_registry, test_base::USER_2()),
            false,
        );

        ts::return_shared(relayer_registry);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

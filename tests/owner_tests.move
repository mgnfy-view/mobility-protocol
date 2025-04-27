#[test_only]
module mobility_protocol::owner_tests;

use mobility_protocol::owner;
use mobility_protocol::test_base;

#[test]
public fun creating_owner_cap_object_succeeds() {
    let global_state = test_base::setup(false, false, false, false, false);

    let global_state = test_base::forward_scenario(global_state, test_base::OWNER());
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
        scenario.return_to_sender(owner_cap);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun no_other_user_can_have_owner_cap() {
    let global_state = test_base::setup(false, false, false, false, false);

    let global_state = test_base::forward_scenario(global_state, test_base::USER_1());
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
        scenario.return_to_sender(owner_cap);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun owner_cap_can_be_transferred() {
    let global_state = test_base::setup(false, false, false, false, false);

    let global_state = test_base::forward_scenario(global_state, test_base::OWNER());
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
        transfer::public_transfer(owner_cap, test_base::USER_1());
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
        scenario.return_to_sender(owner_cap);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test_only]
module mobility_protocol::test_base;

use mobility_protocol::manage_relayers;
use mobility_protocol::owner;
use sui::clock;
use sui::test_scenario as ts;

public struct GlobalState {
    scenario: ts::Scenario,
    clock: clock::Clock,
}

public fun setup(): GlobalState {
    let mut scenario = ts::begin(OWNER());
    let scenario_ref = &mut scenario;

    let clock = clock::create_for_testing(scenario_ref.ctx());
    clock.share_for_testing();

    ts::next_tx(scenario_ref, OWNER());

    let clock = scenario_ref.take_shared<clock::Clock>();
    owner::init_for_testing(scenario_ref.ctx());
    manage_relayers::init_for_testing(scenario_ref.ctx());

    GlobalState {
        scenario,
        clock,
    }
}

public fun forward_scenario(global_state: GlobalState, user: address): GlobalState {
    let GlobalState { mut scenario, clock } = global_state;
    let scenario_ref = &mut scenario;

    ts::return_shared(clock);

    scenario_ref.next_tx(user);

    let clock = scenario.take_shared<clock::Clock>();

    GlobalState { scenario, clock }
}

public fun cleanup(global_state: GlobalState) {
    let GlobalState { scenario, clock } = global_state;

    clock.destroy_for_testing();

    scenario.end();
}

public fun unwrap_global_state(global_state: GlobalState): (ts::Scenario, clock::Clock) {
    let GlobalState { scenario, clock } = global_state;

    (scenario, clock)
}

public fun wrap_global_state(scenario: ts::Scenario, clock: clock::Clock): GlobalState {
    GlobalState { scenario, clock }
}

public fun USER_1(): address { @0x12345 }

public fun USER_2(): address { @0x54321 }

public fun OWNER(): address { @0xABCDE }

public fun RELAYER_1(): address { @0xEDCBA }

public fun RELAYER_2(): address { @0xFEDCB }

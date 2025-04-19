#[test_only]
module mobility_protocol::test_base;

use mobility_protocol::attest_btc_deposit;
use mobility_protocol::create_lending_pools;
use mobility_protocol::manage_relayers;
use mobility_protocol::one_time_witness_registry;
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

    one_time_witness_registry::init_for_testing(scenario_ref.ctx());
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

public fun set_relayers(
    scenario: &ts::Scenario,
    mut relayers: vector<address>,
    mut is_active: vector<bool>,
) {
    let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
    let mut relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();

    let mut relayer_count = relayers.length();

    while (relayer_count > 0) {
        manage_relayers::set_relayer(
            &owner_cap,
            &mut relayer_registry,
            relayers.pop_back(),
            is_active.pop_back(),
        );

        relayer_count = relayer_count - 1;
    };

    scenario.return_to_sender(owner_cap);
    ts::return_shared(relayer_registry);
}

public fun create_collateral_proof(scenario: &mut ts::Scenario, mut users: vector<address>) {
    let mut one_time_witness_registry = scenario.take_shared<
        one_time_witness_registry::OneTimeWitnessRegistry,
    >();
    let mut user_count = users.length();

    while (user_count > 0) {
        attest_btc_deposit::create_collateral_proof(
            &mut one_time_witness_registry,
            users.pop_back(),
            scenario.ctx(),
        );

        user_count = user_count - 1;
    };

    ts::return_shared(one_time_witness_registry);
}

public fun attest_btc_deposit(scenario: &mut ts::Scenario, btc_txn_hash: vector<u8>, amount: u64) {
    let mut relayer_registry = scenario.take_shared<manage_relayers::RelayerRegistry>();
    let mut collateral_proof = scenario.take_shared<attest_btc_deposit::CollateralProof>();

    attest_btc_deposit::attest_btc_deposit(
        &mut relayer_registry,
        &mut collateral_proof,
        btc_txn_hash,
        amount,
        scenario.ctx(),
    );

    ts::return_shared(relayer_registry);
    ts::return_shared(collateral_proof);
}

public fun create_lending_pool_wrapper<CoinType>(scenario: &mut ts::Scenario) {
    let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
    let mut one_time_witness_registry = scenario.take_shared<
        one_time_witness_registry::OneTimeWitnessRegistry,
    >();

    create_lending_pools::create_lending_pool_wrapper<CoinType>(
        &owner_cap,
        &mut one_time_witness_registry,
        scenario.ctx(),
    );

    ts::return_to_sender(scenario, owner_cap);
    ts::return_shared(one_time_witness_registry);
}

public fun create_sub_lending_pool<CoinType>(
    scenario: &mut ts::Scenario,
    lending_duration: u64,
    interest_rate_in_bps: u16,
    clock: &clock::Clock,
) {
    let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
    let mut lending_pool_wrapper = scenario.take_shared<
        create_lending_pools::LendingPoolWrapper<CoinType>,
    >();

    create_lending_pools::create_sub_lending_pool<CoinType>(
        &mut lending_pool_wrapper,
        clock,
        lending_duration,
        interest_rate_in_bps,
    );

    ts::return_to_sender(scenario, owner_cap);
    ts::return_shared(lending_pool_wrapper);
}

public fun USER_1(): address { @0x12345 }

public fun USER_2(): address { @0x54321 }

public fun OWNER(): address { @0xABCDE }

public fun RELAYER_1(): address { @0xEDCBA }

public fun RELAYER_2(): address { @0xFEDCB }

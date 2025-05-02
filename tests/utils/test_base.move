#[test_only]
module mobility_protocol::test_base;

use mobility_protocol::attest_btc_deposit;
use mobility_protocol::constants;
use mobility_protocol::create_lending_pools;
use mobility_protocol::lenders;
use mobility_protocol::manage_relayers;
use mobility_protocol::one_time_witness_registry;
use mobility_protocol::owner;
use sui::clock;
use sui::coin;
use sui::sui::SUI;
use sui::test_scenario as ts;

public struct GlobalState {
    scenario: ts::Scenario,
    clock: clock::Clock,
}

public fun setup(
    create_collateral_proofs: bool,
    setup_relayers: bool,
    setup_lending_pool: bool,
    setup_sub_lending_pool: bool,
    create_sub_lending_pool_positions: bool,
): GlobalState {
    let mut scenario = ts::begin(OWNER());
    let scenario_ref = &mut scenario;

    let clock = clock::create_for_testing(scenario_ref.ctx());
    clock.share_for_testing();

    ts::next_tx(scenario_ref, OWNER());

    let clock = scenario_ref.take_shared<clock::Clock>();

    one_time_witness_registry::init_for_testing(scenario_ref.ctx());
    owner::init_for_testing(scenario_ref.ctx());
    manage_relayers::init_for_testing(scenario_ref.ctx());

    let global_state = forward_scenario(wrap_global_state(scenario, clock), OWNER());
    let (mut scenario, clock) = unwrap_global_state(global_state);

    if (create_collateral_proofs) {
        create_collateral_proof(&mut scenario, vector[USER_1(), USER_2()]);
    };

    if (setup_relayers) {
        set_relayers(&scenario, vector[RELAYER_1(), RELAYER_2()], vector[true, true]);
    };

    let global_state = forward_scenario(
        wrap_global_state(scenario, clock),
        OWNER(),
    );
    let (mut scenario, clock) = unwrap_global_state(global_state);

    if (setup_lending_pool) {
        let (ltv, grace_period, aggregator_id) = get_sample_lending_pool_parameters();
        create_lending_pool_wrapper<SUI>(
            &mut scenario,
            ltv,
            grace_period,
            aggregator_id,
        );
    };

    let global_state = forward_scenario(
        wrap_global_state(scenario, clock),
        OWNER(),
    );
    let (mut scenario, clock) = unwrap_global_state(global_state);
    let (lending_duration, interest_rate_in_bps) = get_sample_sub_lending_pool_parameters();

    if (setup_sub_lending_pool) {
        create_sub_lending_pool<SUI>(
            &mut scenario,
            lending_duration,
            interest_rate_in_bps,
            &clock,
        );
    };

    let global_state = forward_scenario(
        wrap_global_state(scenario, clock),
        USER_1(),
    );
    let (mut scenario, clock) = unwrap_global_state(global_state);

    if (create_sub_lending_pool_positions) {
        create_sub_lending_pool_positions<SUI>(
            &mut scenario,
            lending_duration,
            interest_rate_in_bps,
        );
    };

    let global_state = forward_scenario(
        wrap_global_state(scenario, clock),
        USER_2(),
    );
    let (mut scenario, clock) = unwrap_global_state(global_state);

    if (create_sub_lending_pool_positions) {
        create_sub_lending_pool_positions<SUI>(
            &mut scenario,
            lending_duration,
            interest_rate_in_bps,
        );
    };

    let initial_mint_amount = 1_000_000_000_000;
    get_coins<SUI>(&mut scenario, USER_1(), initial_mint_amount);
    get_coins<SUI>(&mut scenario, USER_2(), initial_mint_amount);

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

public fun get_coins<CoinType>(scenario: &mut ts::Scenario, user: address, amount: u64) {
    let coin = coin::mint_for_testing<CoinType>(amount, scenario.ctx());

    transfer::public_transfer(coin, user);
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

public fun create_lending_pool_wrapper<CoinType>(
    scenario: &mut ts::Scenario,
    ltv: u16,
    grace_period: u64,
    aggregator_id: object::ID,
) {
    let owner_cap = scenario.take_from_sender<owner::OwnerCap>();
    let mut one_time_witness_registry = scenario.take_shared<
        one_time_witness_registry::OneTimeWitnessRegistry,
    >();

    create_lending_pools::create_lending_pool_wrapper<CoinType>(
        &owner_cap,
        &mut one_time_witness_registry,
        ltv,
        grace_period,
        aggregator_id,
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

public fun create_sub_lending_pool_positions<CoinType>(
    scenario: &mut ts::Scenario,
    lending_duration: u64,
    interest_rate_in_bps: u16,
) {
    let lending_pool_wrapper = scenario.take_shared<
        create_lending_pools::LendingPoolWrapper<CoinType>,
    >();

    lenders::create_position(
        &lending_pool_wrapper,
        lending_duration,
        interest_rate_in_bps,
        scenario.ctx(),
    );

    ts::return_shared(lending_pool_wrapper);
}

public fun supply<CoinType>(
    scenario: &mut ts::Scenario,
    clock: &clock::Clock,
    lending_duration: u64,
    interest_rate_in_bps: u16,
    supply_amount: u64,
) {
    let mut lending_pool_wrapper = scenario.take_shared<
        create_lending_pools::LendingPoolWrapper<CoinType>,
    >();
    let mut position = scenario.take_from_sender<lenders::Position>();
    let mut coin = scenario.take_from_sender<coin::Coin<CoinType>>();
    let supply_coin = coin.split(supply_amount, scenario.ctx());

    lenders::supply<CoinType>(
        &mut lending_pool_wrapper,
        &mut position,
        clock,
        lending_duration,
        interest_rate_in_bps,
        supply_coin,
        scenario.ctx(),
    );

    ts::return_shared(lending_pool_wrapper);
    scenario.return_to_sender(position);
    ts::return_to_sender(scenario, coin);
}

public fun withdraw<CoinType>(
    scenario: &mut ts::Scenario,
    clock: &clock::Clock,
    lending_duration: u64,
    interest_rate_in_bps: u16,
    withdraw_amount: u64,
) {
    let mut lending_pool_wrapper = scenario.take_shared<
        create_lending_pools::LendingPoolWrapper<CoinType>,
    >();
    let mut position = scenario.take_from_sender<lenders::Position>();

    lenders::withdraw(
        &mut lending_pool_wrapper,
        &mut position,
        clock,
        withdraw_amount,
        lending_duration,
        interest_rate_in_bps,
        scenario.ctx(),
    );

    ts::return_shared(lending_pool_wrapper);
    scenario.return_to_sender(position);
}

public fun get_sample_attestation_data(): (vector<u8>, u64) {
    let btc_txn_hash = b"8ccbc0e4c22bad9803cfb2b8445eae740db30f63a3d4ef9fd6d855884f6eeeb6";
    let amount = 1 * constants::BASE_SCALING_FACTOR();

    (btc_txn_hash, amount)
}

public fun get_sample_lending_pool_parameters(): (u16, u64, object::ID) {
    let ltv = 6_000;
    let grace_period = 43_200;

    (ltv, grace_period, object::id_from_address(@sui_usd_switchboard_aggregator))
}

public fun get_sample_sub_lending_pool_parameters(): (u64, u16) {
    let lending_duration = 86_400;
    let interest_rate_in_bps = 1_000;

    (lending_duration, interest_rate_in_bps)
}

public fun USER_1(): address { @0x12345 }

public fun USER_2(): address { @0x54321 }

public fun OWNER(): address { @0xABCDE }

public fun RELAYER_1(): address { @0xEDCBA }

public fun RELAYER_2(): address { @0xFEDCB }

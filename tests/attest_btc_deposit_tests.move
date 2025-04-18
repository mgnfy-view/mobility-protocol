#[test_only]
module mobility_protocol::attest_btc_deposit_tests;

use mobility_protocol::attest_btc_deposit;
use mobility_protocol::constants;
use mobility_protocol::test_base;
use sui::test_scenario as ts;
use sui::test_utils as tu;

#[test]
public fun creating_collateral_proof_succeeds() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::set_relayers(
            &scenario,
            vector[test_base::RELAYER_1(), test_base::RELAYER_2()],
            vector[true, true],
        );
        test_base::create_collateral_proof(&mut scenario, vector[test_base::USER_1()]);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let collateral_proof = scenario.take_shared<attest_btc_deposit::CollateralProof>();

        tu::assert_eq(attest_btc_deposit::get_user(&collateral_proof), scenario.ctx().sender());
        tu::assert_eq(attest_btc_deposit::get_btc_collateral_deposited(&collateral_proof), 0);
        tu::assert_eq(attest_btc_deposit::get_btc_collateral_used(&collateral_proof), 0);

        ts::return_shared(collateral_proof);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun cannot_create_collateral_proof_twice() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::set_relayers(
            &scenario,
            vector[test_base::RELAYER_1(), test_base::RELAYER_2()],
            vector[true, true],
        );
        test_base::create_collateral_proof(&mut scenario, vector[test_base::USER_1()]);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::create_collateral_proof(&mut scenario, vector[test_base::USER_1()]);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun non_relayer_cannot_attest_deposits() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    { test_base::create_collateral_proof(&mut scenario, vector[test_base::USER_1()]); };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (btc_txn_hash, amount) = get_sample_attestation_data();

    {
        test_base::attest_btc_deposit(&mut scenario, btc_txn_hash, amount);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun relayer_can_attest_deposits() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::set_relayers(
            &scenario,
            vector[test_base::RELAYER_1(), test_base::RELAYER_2()],
            vector[true, true],
        );
        test_base::create_collateral_proof(&mut scenario, vector[test_base::USER_1()]);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::RELAYER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (btc_txn_hash, amount) = get_sample_attestation_data();

    {
        test_base::attest_btc_deposit(&mut scenario, btc_txn_hash, amount);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::RELAYER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let collateral_proof = scenario.take_shared<attest_btc_deposit::CollateralProof>();

        tu::assert_eq(
            attest_btc_deposit::has_relayer_attested(
                &collateral_proof,
                btc_txn_hash,
                amount,
                test_base::RELAYER_1(),
            ),
            true,
        );
        tu::assert_eq(
            attest_btc_deposit::has_attestation_passed(&collateral_proof, btc_txn_hash, amount),
            false,
        );
        tu::assert_eq(
            attest_btc_deposit::get_attestation_count(&collateral_proof, btc_txn_hash, amount),
            1,
        );

        ts::return_shared(collateral_proof);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun attestation_passes() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::set_relayers(
            &scenario,
            vector[test_base::RELAYER_1(), test_base::RELAYER_2()],
            vector[true, true],
        );
        test_base::create_collateral_proof(&mut scenario, vector[test_base::USER_1()]);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::RELAYER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (btc_txn_hash, amount) = get_sample_attestation_data();

    {
        test_base::attest_btc_deposit(&mut scenario, btc_txn_hash, amount);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::RELAYER_2(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::attest_btc_deposit(&mut scenario, btc_txn_hash, amount);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::RELAYER_2(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let collateral_proof = scenario.take_shared<attest_btc_deposit::CollateralProof>();

        tu::assert_eq(
            attest_btc_deposit::has_relayer_attested(
                &collateral_proof,
                btc_txn_hash,
                amount,
                test_base::RELAYER_1(),
            ),
            true,
        );
        tu::assert_eq(
            attest_btc_deposit::has_relayer_attested(
                &collateral_proof,
                btc_txn_hash,
                amount,
                test_base::RELAYER_2(),
            ),
            true,
        );
        tu::assert_eq(
            attest_btc_deposit::has_attestation_passed(&collateral_proof, btc_txn_hash, amount),
            true,
        );
        tu::assert_eq(
            attest_btc_deposit::get_attestation_count(&collateral_proof, btc_txn_hash, amount),
            2,
        );

        ts::return_shared(collateral_proof);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun cannot_attest_after_attestation_passes() {
    let global_state = test_base::setup();

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::set_relayers(
            &scenario,
            vector[test_base::RELAYER_1(), test_base::RELAYER_2()],
            vector[true, true],
        );
        test_base::create_collateral_proof(&mut scenario, vector[test_base::USER_1()]);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::RELAYER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (btc_txn_hash, amount) = get_sample_attestation_data();

    {
        test_base::attest_btc_deposit(&mut scenario, btc_txn_hash, amount);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::RELAYER_2(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::attest_btc_deposit(&mut scenario, btc_txn_hash, amount);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::RELAYER_2(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::attest_btc_deposit(&mut scenario, btc_txn_hash, amount);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

fun get_sample_attestation_data(): (vector<u8>, u64) {
    let btc_txn_hash = b"8ccbc0e4c22bad9803cfb2b8445eae740db30f63a3d4ef9fd6d855884f6eeeb6";
    let amount = 1 * constants::BTC_AMOUNT_SCALING_FACTOR();

    (btc_txn_hash, amount)
}

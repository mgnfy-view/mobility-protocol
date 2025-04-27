#[test_only]
module mobility_protocol::attest_btc_deposit_tests;

use mobility_protocol::attest_btc_deposit;
use mobility_protocol::test_base;
use sui::test_scenario as ts;
use sui::test_utils as tu;

#[test]
public fun creating_collateral_proof_succeeds() {
    let global_state = test_base::setup(true, false, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let collateral_proof = scenario.take_shared<attest_btc_deposit::CollateralProof>();
        let (
            user,
            btc_collateral_deposited,
            btc_collateral_used,
        ) = collateral_proof.get_collateral_proof_info();

        tu::assert_eq(user, scenario.ctx().sender());
        tu::assert_eq(btc_collateral_deposited, 0);
        tu::assert_eq(btc_collateral_used, 0);

        ts::return_shared(collateral_proof);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun cannot_create_collateral_proof_twice_for_the_same_user() {
    let global_state = test_base::setup(true, false, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::OWNER(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    { test_base::create_collateral_proof(&mut scenario, vector[test_base::USER_1()]); };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun non_relayer_cannot_attest_deposits() {
    let global_state = test_base::setup(true, false, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (btc_txn_hash, amount) = test_base::get_sample_attestation_data();

    {
        test_base::attest_btc_deposit(&mut scenario, btc_txn_hash, amount);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun relayer_can_attest_deposits() {
    let global_state = test_base::setup(true, true, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::RELAYER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (btc_txn_hash, amount) = test_base::get_sample_attestation_data();

    {
        test_base::attest_btc_deposit(&mut scenario, btc_txn_hash, amount);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let collateral_proof = scenario.take_shared<attest_btc_deposit::CollateralProof>();

        tu::assert_eq(
            collateral_proof.has_relayer_attested(
                btc_txn_hash,
                amount,
                test_base::RELAYER_1(),
            ),
            true,
        );
        tu::assert_eq(
            collateral_proof.has_attestation_passed(btc_txn_hash, amount),
            false,
        );
        tu::assert_eq(
            collateral_proof.get_attestation_count(btc_txn_hash, amount),
            1,
        );

        ts::return_shared(collateral_proof);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun relayer_cannot_attest_the_same_deposit_twice() {
    let global_state = test_base::setup(true, true, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::RELAYER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (btc_txn_hash, amount) = test_base::get_sample_attestation_data();

    {
        test_base::attest_btc_deposit(&mut scenario, btc_txn_hash, amount);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::RELAYER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        test_base::attest_btc_deposit(&mut scenario, btc_txn_hash, amount);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test]
public fun attestation_passes() {
    let global_state = test_base::setup(true, true, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::RELAYER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (btc_txn_hash, amount) = test_base::get_sample_attestation_data();

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
        test_base::USER_1(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let collateral_proof = scenario.take_shared<attest_btc_deposit::CollateralProof>();

        tu::assert_eq(
            collateral_proof.has_relayer_attested(
                btc_txn_hash,
                amount,
                test_base::RELAYER_1(),
            ),
            true,
        );
        tu::assert_eq(
            collateral_proof.has_relayer_attested(
                btc_txn_hash,
                amount,
                test_base::RELAYER_2(),
            ),
            true,
        );
        tu::assert_eq(
            collateral_proof.has_attestation_passed(btc_txn_hash, amount),
            true,
        );
        tu::assert_eq(
            collateral_proof.get_attestation_count(btc_txn_hash, amount),
            2,
        );

        let (
            user,
            btc_collateral_deposited,
            btc_collateral_used,
        ) = collateral_proof.get_collateral_proof_info();

        tu::assert_eq(user, test_base::USER_1());
        tu::assert_eq(btc_collateral_deposited, amount);
        tu::assert_eq(btc_collateral_used, 0);

        ts::return_shared(collateral_proof);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

#[test, expected_failure]
public fun cannot_attest_after_attestation_passes() {
    let global_state = test_base::setup(true, true, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::RELAYER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (btc_txn_hash, amount) = test_base::get_sample_attestation_data();

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

#[test]
public fun can_initiate_withdrawal_request() {
    let global_state = test_base::setup(true, true, false, false);

    let global_state = test_base::forward_scenario(
        global_state,
        test_base::RELAYER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let (btc_txn_hash, amount) = test_base::get_sample_attestation_data();

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
        test_base::USER_1(),
    );
    let (mut scenario, clock) = test_base::unwrap_global_state(global_state);
    let sample_btc_address = b"37jKPSmbEGwgfacCr2nayn1wTaqMAbA94Z";

    {
        let mut collateral_proof = scenario.take_shared<attest_btc_deposit::CollateralProof>();

        collateral_proof.withdraw_btc(amount, sample_btc_address, scenario.ctx());

        ts::return_shared(collateral_proof);
    };

    let global_state = test_base::forward_scenario(
        test_base::wrap_global_state(scenario, clock),
        test_base::RELAYER_2(),
    );
    let (scenario, clock) = test_base::unwrap_global_state(global_state);

    {
        let collateral_proof = scenario.take_shared<attest_btc_deposit::CollateralProof>();

        let (
            user,
            btc_collateral_deposited,
            btc_collateral_used,
        ) = collateral_proof.get_collateral_proof_info();

        tu::assert_eq(user, test_base::USER_1());
        tu::assert_eq(btc_collateral_deposited, 0);
        tu::assert_eq(btc_collateral_used, 0);

        ts::return_shared(collateral_proof);
    };

    test_base::cleanup(test_base::wrap_global_state(scenario, clock));
}

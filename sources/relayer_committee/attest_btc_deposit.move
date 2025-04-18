module mobility_protocol::attest_btc_deposit;

use mobility_protocol::config;
use mobility_protocol::constants;
use mobility_protocol::errors;
use mobility_protocol::manage_relayers;
use mobility_protocol::one_time_witness_registry;
use sui::event;
use sui::table;

// ===== Global storage structs =====

public struct AttestationData has copy, drop, store {
    btc_txn_hash: vector<u8>,
    amount: u64,
}

public struct AttestationRelayerInfo has store {
    attesting_relayers: table::Table<address, bool>,
    attestation_count: u64,
    passed: bool,
}

public struct CollateralProof has key {
    id: object::UID,
    user: address,
    btc_collateral_deposited: u64, // scaled by 1e9
    btc_collateral_used: u64,
    btc_deposits_attestations: table::Table<AttestationData, AttestationRelayerInfo>,
}

// ===== Events =====

public struct CollateralProofCreated has copy, drop {
    id: object::ID,
    user: address,
}

public struct RelayerAttested has copy, drop {
    relayer: address,
    user: address,
    attestation_data: AttestationData,
    attestation_count: u64,
}

public struct AttestationThresholdPassed has copy, drop {
    user: address,
    attestation_data: AttestationData,
    attestation_count: u64,
}

// ===== Public functions =====

public entry fun create_collateral_proof(
    one_time_witness_registry: &mut one_time_witness_registry::OneTimeWitnessRegistry,
    user: address,
    ctx: &mut TxContext,
) {
    one_time_witness_registry::use_witness<address>(
        one_time_witness_registry,
        config::btc_attestation_domain(),
        user,
        ctx,
    );

    let collateral_proof = CollateralProof {
        id: object::new(ctx),
        user,
        btc_collateral_deposited: 0,
        btc_collateral_used: 0,
        btc_deposits_attestations: table::new(ctx),
    };

    let collateral_proof_id = collateral_proof.id.to_inner();
    event::emit(CollateralProofCreated {
        id: collateral_proof_id,
        user,
    });

    transfer::share_object(collateral_proof);
}

public entry fun attest_btc_deposit(
    relayer_registry: &mut manage_relayers::RelayerRegistry,
    collateral_proof: &mut CollateralProof,
    btc_txn_hash: vector<u8>,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert!(
        manage_relayers::is_whitelisted_relayer(relayer_registry, ctx.sender()),
        errors::not_whitelisted_relayer(),
    );
    assert!(amount > 0, errors::amount_zero());

    let attestation_data = AttestationData {
        btc_txn_hash,
        amount,
    };

    if (collateral_proof.btc_deposits_attestations.contains(attestation_data)) {
        let attestation_relayer_info = collateral_proof
            .btc_deposits_attestations
            .borrow_mut(attestation_data);
        let has_attested = attestation_relayer_info.attesting_relayers.contains(ctx.sender());

        assert!(!attestation_relayer_info.passed, errors::already_passed_attestation_threshold());
        assert!(!has_attested, errors::already_attested());

        attestation_relayer_info.attesting_relayers.add(ctx.sender(), true);
        attestation_relayer_info.attestation_count = attestation_relayer_info.attestation_count + 1;

        event::emit(RelayerAttested {
            relayer: ctx.sender(),
            user: collateral_proof.user,
            attestation_data,
            attestation_count: attestation_relayer_info.attestation_count,
        });

        let attestation_percentage =
            (
                (attestation_relayer_info.attestation_count * (constants::BASIS_POINTS() as u64))
                    / manage_relayers::get_relayer_count(relayer_registry),
            ) as u16;
        let passing_attestation_threshold =
            attestation_percentage > config::attestations_threshold_in_bps();
        if (passing_attestation_threshold) {
            attestation_relayer_info.passed = true;
            collateral_proof.btc_collateral_deposited =
                collateral_proof.btc_collateral_deposited + attestation_data.amount;
        };

        event::emit(AttestationThresholdPassed {
            user: collateral_proof.user,
            attestation_data,
            attestation_count: attestation_relayer_info.attestation_count,
        });
    } else {
        let attestation_count = 1;

        let mut attestation_relayer_info = AttestationRelayerInfo {
            attesting_relayers: table::new(ctx),
            attestation_count,
            passed: false,
        };
        attestation_relayer_info.attesting_relayers.add(ctx.sender(), true);
        collateral_proof.btc_deposits_attestations.add(attestation_data, attestation_relayer_info);

        event::emit(RelayerAttested {
            relayer: ctx.sender(),
            user: collateral_proof.user,
            attestation_data,
            attestation_count: attestation_count,
        });
    };
}

// ===== View functions =====

public fun get_user(collateral_proof: &CollateralProof): address {
    collateral_proof.user
}

public fun get_btc_collateral_deposited(collateral_proof: &CollateralProof): u64 {
    collateral_proof.btc_collateral_deposited
}

public fun get_btc_collateral_used(collateral_proof: &CollateralProof): u64 {
    collateral_proof.btc_collateral_used
}

public fun has_relayer_attested(
    collateral_proof: &CollateralProof,
    btc_txn_hash: vector<u8>,
    amount: u64,
    relayer: address,
): bool {
    let attestation_data = AttestationData {
        btc_txn_hash,
        amount,
    };

    if (collateral_proof.btc_deposits_attestations.contains(attestation_data)) {
        collateral_proof
            .btc_deposits_attestations
            .borrow(attestation_data)
            .attesting_relayers
            .contains(relayer)
    } else {
        false
    }
}

public fun get_attestation_count(
    collateral_proof: &CollateralProof,
    btc_txn_hash: vector<u8>,
    amount: u64,
): u64 {
    let attestation_data = AttestationData {
        btc_txn_hash,
        amount,
    };

    if (collateral_proof.btc_deposits_attestations.contains(attestation_data)) {
        collateral_proof.btc_deposits_attestations.borrow(attestation_data).attestation_count
    } else {
        0
    }
}

public fun has_attestation_passed(
    collateral_proof: &CollateralProof,
    btc_txn_hash: vector<u8>,
    amount: u64,
): bool {
    let attestation_data = AttestationData {
        btc_txn_hash,
        amount,
    };

    if (collateral_proof.btc_deposits_attestations.contains(attestation_data)) {
        collateral_proof.btc_deposits_attestations.borrow(attestation_data).passed
    } else {
        false
    }
}

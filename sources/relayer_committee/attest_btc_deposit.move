module mobility_protocol::attest_btc_deposit;

use mobility_protocol::config;
use mobility_protocol::constants;
use mobility_protocol::errors;
use mobility_protocol::manage_relayers;
use mobility_protocol::one_time_witness_registry;
use mobility_protocol::utils;
use sui::event;
use sui::table;

// ===== Global storage structs =====

/// Serves as the collateral proof to borrow coins against.
/// Also stores attestation data.
public struct CollateralProof has key {
    id: object::UID,
    user: address,
    btc_collateral_deposited: u64, // scaled by 1e9
    btc_collateral_used: u64,
    btc_deposits_attestations: table::Table<AttestationData, AttestationRelayerInfo>,
}

/// The attestation data key. Stores the btc txn hash and the btc amount bridged.
public struct AttestationData has copy, drop, store {
    btc_txn_hash: vector<u8>,
    amount: u64,
}

/// The attesting relayer info for an attestation data key. Tracks the number of
/// attestations so far, the attesting relayers, and whether the attestation has passed
/// the predefined threshold.
public struct AttestationRelayerInfo has store {
    attesting_relayers: table::Table<address, bool>,
    attestation_count: u64,
    passed: bool,
}

// ===== Events =====

/// Emitted when a collateral proof object is created for a user.
public struct CollateralProofCreated has copy, drop {
    id: object::ID,
    user: address,
}

/// Emitted when a relayer attests a btc bridging txn.
public struct RelayerAttested has copy, drop {
    relayer: address,
    user: address,
    attestation_data: AttestationData,
    attestation_count: u64,
}

/// Emitted when an attestation passes, activating the btc collateral to be
/// used for borrowing.
public struct AttestationThresholdPassed has copy, drop {
    user: address,
    attestation_data: AttestationData,
    attestation_count: u64,
}

/// Emitted when the user wants to withdraw their bridged btc. The relayer network
/// picks this up and releases the funds on Bitcoin network.
public struct WithdrawRequest has copy, drop {
    user: address,
    btc_address: vector<u8>,
    amount: u64,
}

// ===== Public functions =====

/// Allows anyone to create a collateral proof object for any address. If the attestation threshold
/// passes, the bridged btc is activated to be used as collateral for borrowing.
///
/// Args:
///
/// one_time_witness_registry:  Immutable reference to the one time witness
///                             registry shared object.
/// user:                       The user to create the collateral proof object for.
/// ctx:                        The transaction context.
public entry fun create_collateral_proof(
    one_time_witness_registry: &mut one_time_witness_registry::OneTimeWitnessRegistry,
    user: address,
    ctx: &mut TxContext,
) {
    one_time_witness_registry.use_witness(
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

    event::emit(CollateralProofCreated {
        id: collateral_proof.id.to_inner(),
        user,
    });

    transfer::share_object(collateral_proof);
}

/// Allows relayers to attest valid btc bridging txns.
///
/// Args:
///
/// relayer_registry:   Immutable reference to the one time witness
///                     registry shared object.
/// collateral_proof:   A user's collateral proof object.
/// btc_txn_hash:       Hash of the btc txn where the user deposited their btc to the
///                     platform's wallet address.
/// amount:             The amount of btc bridged (scaled by 1e9, the base scaling factor).
/// ctx:                The transaction context.
public entry fun attest_btc_deposit(
    relayer_registry: &mut manage_relayers::RelayerRegistry,
    collateral_proof: &mut CollateralProof,
    btc_txn_hash: vector<u8>,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert!(
        relayer_registry.is_whitelisted_relayer(ctx.sender()),
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
                utils::mul_div_u64(
                    attestation_relayer_info.attestation_count,
                    (constants::BASIS_POINTS() as u64),
                    relayer_registry.get_relayer_count(),
                ),
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

/// Debits a user's bridged btc, and emits a withdraw request event to be picked up and
/// fulfilled by relayers on the Bitcoin network.
///
/// Args:
///
/// collateral_proof:   A user's collateral proof object.
/// amount:             The amount of btc to bridge back (scaled by 1e9, the base scaling factor).
/// btc_address:        The recipient of the withdrawn btc on the Bitcoin network.
public entry fun withdraw_btc(
    collateral_proof: &mut CollateralProof,
    amount: u64,
    btc_address: vector<u8>,
) {
    let max_withdrawable_amount =
        collateral_proof.btc_collateral_deposited - collateral_proof.btc_collateral_used;
    assert!(amount <= max_withdrawable_amount, errors::insufficient_balance());

    collateral_proof.btc_collateral_deposited = collateral_proof.btc_collateral_deposited - amount;

    event::emit(WithdrawRequest {
        user: collateral_proof.user,
        btc_address,
        amount,
    });
}

// ===== View functions =====

/// Gets the collateral proof details.
///
/// Args:
///
/// collateral_proof: A user's collateral proof object.
///
/// Returns the user address, the deposited btc amount (scaled by 1e9, the base scaling factor),
/// and the btc amount used accross loans (also scaled by the base scaling factor).
public fun get_collateral_proof_info(collateral_proof: &CollateralProof): (address, u64, u64) {
    (
        collateral_proof.user,
        collateral_proof.btc_collateral_deposited,
        collateral_proof.btc_collateral_used,
    )
}

/// Checks if a relayer has attested a btc bridging txn.
///
/// Args:
///
/// collateral_proof:   A user's collateral proof object.
/// btc_txn_hash:       Hash of the btc txn where the user deposited their btc to the
///                     platform's wallet address.
/// amount:             The amount of btc bridged (scaled by 1e9, the base scaling factor).
/// relayer:            The attesting relayer.
///
/// Returns a bool indicating whether a relayer has attested a btc bridging txn or not.
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

/// Gets the number of attestations for the given btc bridging txn.
///
/// Args:
///
/// collateral_proof:   A user's collateral proof object.
/// btc_txn_hash:       Hash of the btc txn where the user deposited their btc to the
///                     platform's wallet address.
/// amount:             The amount of btc bridged (scaled by 1e9, the base scaling factor).
///
/// Returns the total number of attestations for the given btc bridging txn.
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

/// Checks if the given btc bridging txn has passed the attestation threshold.
///
/// Args:
///
/// collateral_proof:   A user's collateral proof object.
/// btc_txn_hash:       Hash of the btc txn where the user deposited their btc to the
///                     platform's wallet address.
/// amount:             The amount of btc bridged (scaled by 1e9, the base scaling factor).
///
/// Returns a bool indicating whether the btc bridging txn has passed the attestation
/// threshold.
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

// ===== Package functions =====

/// Allows friend modules to use btc collateral for borrowing,
///
/// Args:
///
/// collateral_proof:   A user's collateral proof object.
/// amount:             The amount of btc to use (scaled by 1e9, the base scaling factor).
public(package) fun use_btc_collateral(collateral_proof: &mut CollateralProof, amount: u64) {
    assert!(
        amount <= collateral_proof.btc_collateral_deposited - collateral_proof.btc_collateral_used,
        errors::insufficient_balance(),
    );

    collateral_proof.btc_collateral_used = collateral_proof.btc_collateral_used + amount;
}

/// Allows used btc amount for borrow positions to be returned by friend moudles once the
/// position has been closed.
///
/// Args:
///
/// collateral_proof:   A user's collateral proof object.
/// amount:             The amount of btc to return (scaled by 1e9, the base scaling factor).
public(package) fun credit_btc_collateral(collateral_proof: &mut CollateralProof, amount: u64) {
    collateral_proof.btc_collateral_used = collateral_proof.btc_collateral_used - amount;
}

module mobility_protocol::errors;

// ===== View functions =====

/// Thrown when the provided amount is 0.
/// Returns a u64 error code.
public fun amount_zero(): u64 {
    1
}

/// Thrown when the one time witness for the given domain has already been used.
/// Returns a u64 error code.
public fun already_used_domain_one_time_witness(): u64 {
    2
}

/// Thrown when the relayer is being set to a status it is currently in.
/// Returns a u64 error code.
public fun relayer_status_update_not_required(): u64 {
    3
}

/// Thrown when the interacting address is not a whitelisted relayer.
/// Returns a u64 error code.
public fun not_whitelisted_relayer(): u64 {
    4
}

/// Thrown when a relayer tries to attest a btc deposit that it has already
/// attested before.
/// Returns a u64 error code.
public fun already_attested(): u64 {
    5
}

/// Thrown when a relayer tries to attest a btc deposit that has already passed
/// attestation threshold.
/// Returns a u64 error code.
public fun already_passed_attestation_threshold(): u64 {
    6
}

/// Thrown when there's insufficient balance for an action.
/// Returns a u64 error code.
public fun insufficient_balance(): u64 {
    7
}

/// Thrown when the lending pool ltv is either 0 or greater than
/// basis points (10_000).
/// Returns a u64 error code.
public fun invalid_ltv(): u64 {
    8
}

/// Thrown when the lending pool duration is not a multiple of the minimum
/// lending pool duration defined in the `config` module.
/// Returns a u64 error code.
public fun invalid_lending_pool_duration(): u64 {
    9
}

/// Thrown when the interest rate is not a multiple of the minimum
/// interest rate defined in the `config` module.
/// Returns a u64 error code.
public fun invalid_interest_rate(): u64 {
    10
}

/// Thrown when trying to create a sub lending pool that already exists.
/// Returns a u64 error code.
public fun sub_lending_pool_already_exists(): u64 {
    11
}

/// Thrown when the lending pool wrapper id doesn't match the one defined in the position.
/// Returns a u64 error code.
public fun invalid_position(): u64 {
    12
}

/// Thrown when there's insufficient liquidity available in the sub lending pool.
/// Returns a u64 error code.
public fun insufficient_liquidity(): u64 {
    13
}

/// Thrown when the caller is not the owner of the collateral proof object.
/// Returns a u64 error code.
public fun not_collateral_proof_owner(): u64 {
    14
}

/// Thrown when there's a mismatch between the expected oracle aggregator id and the one passed
/// in the function.
/// Returns a u64 error code.
public fun invalid_oracle(): u64 {
    15
}

/// Thrown when there's a mismatch between the expected lending pool id and the one passed
/// in the function.
/// Returns a u64 error code.
public fun invalid_lending_pool(): u64 {
    16
}

/// Thrown when trying to repay a debt that's already been repaid.
/// Returns a u64 error code.
public fun already_repaid(): u64 {
    17
}

/// Thrown when trying to repay a debt that's already liquidated.
/// Returns a u64 error code.
public fun already_liquidated(): u64 {
    18
}

/// Thrown when the amount repaid for a flash borrow is not equal to the initial
/// borrow amount.
/// Returns a u64 error code.
public fun flash_borrow_failed(): u64 {
    19
}

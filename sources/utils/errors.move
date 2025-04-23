module mobility_protocol::errors;

// ===== View functions =====

public fun amount_zero(): u64 {
    1
}

public fun already_used_domain_one_time_witness(): u64 {
    2
}

public fun relayer_status_update_not_required(): u64 {
    3
}

public fun not_whitelisted_relayer(): u64 {
    4
}

public fun already_attested(): u64 {
    5
}

public fun already_passed_attestation_threshold(): u64 {
    6
}

public fun insufficient_balance(): u64 {
    7
}

public fun invalid_lending_pool_duration(): u64 {
    8
}

public fun invalid_interest_rate(): u64 {
    9
}

public fun sub_lending_pool_already_exists(): u64 {
    10
}

public fun invalid_position(): u64 {
    11
}

public fun insufficient_liquidity(): u64 {
    12
}

public fun not_collateral_proof_owner(): u64 {
    13
}

public fun invalid_oracle(): u64 {
    14
}

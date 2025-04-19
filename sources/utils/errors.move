module mobility_protocol::errors;

// ===== View functions =====

public fun relayer_status_update_not_required(): u64 {
    0
}

public fun not_whitelisted_relayer(): u64 {
    1
}

public fun amount_zero(): u64 {
    2
}

public fun already_attested(): u64 {
    3
}

public fun already_passed_attestation_threshold(): u64 {
    4
}

public fun already_used_one_time_witness(): u64 {
    5
}

public fun invalid_lending_pool_duration(): u64 {
    6
}

public fun invalid_interest_rate(): u64 {
    7
}

public fun sub_lending_pool_already_exists(): u64 {
    8
}

public fun insufficient_liquidity(): u64 {
    9
}

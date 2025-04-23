module mobility_protocol::config;

// ===== View functions =====

public fun btc_attestation_domain(): u16 {
    1
}

public fun lending_pool_creation_domain(): u16 {
    2
}

public fun lenders_domain(): u16 {
    3
}

public fun platform_fee_in_bps(): u64 {
    1_000
}

public fun attestations_threshold_in_bps(): u16 {
    5_100
}

public fun lending_interval(): u64 {
    86_400
}

public fun max_lending_duration(): u64 {
    5_184_000
}

public fun interest_rate_increment_in_bps(): u64 {
    100
}

public fun virtual_coins(): u64 {
    1
}

public fun virtual_shares(): u64 {
    1_000
}

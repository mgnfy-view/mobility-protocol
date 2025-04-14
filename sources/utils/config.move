module mobility_protocol::config;

public fun btc_attestation_domain(): u16 {
    1
}

public fun lending_pool_creation_domain(): u16 {
    2
}

public fun attestations_threshold_in_bps(): u16 {
    5_100
}

public fun lending_interval(): u64 {
    86400
}

public fun interest_rate_increment_in_bps(): u64 {
    100
}

public fun platform_fee_in_bps(): u64 {
    1_000
}

module mobility_protocol::config;

// ===== View functions =====

/// One time witness registry domain for `attest_btc_deposit` module.
/// Returns a u16 domain value.
public fun btc_attestation_domain(): u16 {
    1
}

/// One time witness registry domain for `create_lending_pools` module.
/// Returns a u16 domain value.
public fun lending_pool_creation_domain(): u16 {
    2
}

/// Platform fees in basis points.
/// Returns the platform fees in bps.
public fun platform_fee_in_bps(): u64 {
    1_000
}

/// The attestation threshold in bps that needs to be passed for bridged btc
/// to be used as collateral for borrowing.
/// Returns the attestation threshold in bps.
public fun attestations_threshold_in_bps(): u16 {
    5_100
}

/// The minimum lending duration - 1 day. Lending duration increases by this
/// amount for sub-lending pools.
/// Returns the minimum lending duration.
public fun lending_interval(): u64 {
    86_400
}

/// The max lending duration - 2 months.
/// Returns the max lending duration.
public fun max_lending_duration(): u64 {
    5_184_000
}

/// The minimum interest rate in bps - 1%. Interest rate increases by this
/// value for sub-lending pools.
/// Returns the minimum interest rate in bps.
public fun interest_rate_increment_in_bps(): u64 {
    100
}

/// Virtual coin amount to be used in share calculations.
/// Returns the virtual coins value.
public fun virtual_coins(): u64 {
    1
}

/// Virtual share amount to be used in share calculations.
/// Returns the virtual shares value.
public fun virtual_shares(): u64 {
    1_000
}

module mobility_protocol::constants;

// ===== View functions =====

public fun BASIS_POINTS(): u16 {
    10_000
}

public fun BASE_SCALING_FACTOR(): u64 {
    1_000_000_000
}

public fun COMPOUND_INTEREST_SCALING_FACTOR(): u64 {
    1_000_000_000_000_000_000
}

public fun MILLISECONDS_PER_SECOND(): u64 {
    1_000
}

public fun SECONDS_IN_A_YEAR(): u64 {
    31_536_000
}

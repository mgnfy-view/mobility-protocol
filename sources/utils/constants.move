module mobility_protocol::constants;

// ===== View functions =====

/// Basis points.
/// Returns 10_000.
public fun BASIS_POINTS(): u16 {
    10_000
}

/// The base scaling factor to be applied to btc amounts. All btc amounts are scaled
/// by 1e9.
/// Returns 1e9.
public fun BASE_SCALING_FACTOR(): u64 {
    1_000_000_000
}

/// The precision to be used for compound interest calculations.
/// Returns 1e18.
public fun COMPOUND_INTEREST_PRECISION(): u64 {
    1_000_000_000_000_000_000
}

/// Gets the number of milliseconds in a second.
/// Returns the number of milliseconds in a second.
public fun MILLISECONDS_PER_SECOND(): u64 {
    1_000
}

/// Gets the number of seconds on a year.
/// Returns the number of seconds in a year.
public fun SECONDS_IN_A_YEAR(): u64 {
    31_536_000
}

module mobility_protocol::utils;

use mobility_protocol::constants;
use sui::clock;
use switchboard::aggregator::Aggregator;

// ===== View functions =====

public fun mul_div_u64(x: u64, y: u64, z: u64): u64 {
    mul_div_u128(x as u128, y as u128, z as u128) as u64
}

public fun mul_div_u64_to_u128(x: u64, y: u64, z: u64): u128 {
    mul_div_u128(x as u128, y as u128, z as u128)
}

public fun mul_div_u128(x: u128, y: u128, z: u128): u128 {
    (x * y) / z
}

public fun get_taylor_compounded(interest_rate_in_bps: u16, elapsed_time: u64): u128 {
    let scaled_interest_rate_per_second = mul_div_u64_to_u128(
        interest_rate_in_bps as u64,
        constants::COMPOUND_INTEREST_SCALING_FACTOR(),
        ((constants::BASIS_POINTS() as u64) * (constants::SECONDS_IN_A_YEAR() as u64)),
    );

    let first_term = scaled_interest_rate_per_second * (elapsed_time as u128);
    let second_term = mul_div_u128(
        first_term,
        first_term,
        (2 * constants::COMPOUND_INTEREST_SCALING_FACTOR()) as u128,
    );
    let third_term = mul_div_u128(
        second_term,
        first_term,
        (3 * constants::COMPOUND_INTEREST_SCALING_FACTOR()) as u128,
    );

    first_term + second_term + third_term
}

public fun get_time_in_seconds(clock: &clock::Clock): u64 {
    clock.timestamp_ms() / constants::MILLISECONDS_PER_SECOND()
}

public fun get_price(aggregator: &Aggregator): u128 {
    aggregator.current_result().result().value()
}

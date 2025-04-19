module mobility_protocol::utils;

use mobility_protocol::constants;
use sui::clock;

// ===== View functions =====

public fun get_time_in_seconds(clock: &clock::Clock): u64 {
    clock.timestamp_ms() / constants::MILLISECONDS_PER_SECOND()
}

public fun mul_div_u64(x: u64, y: u64, z: u64): u64 {
    (((x as u128) * (y as u128)) / (z as u128)) as u64
}

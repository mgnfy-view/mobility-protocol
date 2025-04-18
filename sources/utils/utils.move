module mobility_protocol::utils;

use mobility_protocol::constants;
use sui::clock;

// ===== View functions =====

public fun get_time_in_seconds(clock: &clock::Clock): u64 {
    clock.timestamp_ms() / constants::MILLISECONDS_PER_SECOND()
}

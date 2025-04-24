module mobility_protocol::version;

use std::string;

// ===== View functions =====

/// Used to track the protocol version on-chain.
/// Returns the version string.
public fun version(): string::String {
    b"1.0.0".to_string()
}

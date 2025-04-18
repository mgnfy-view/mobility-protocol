module mobility_protocol::version;

use std::string;

// ===== View functions =====

public fun version(): string::String {
    b"1.0.0".to_string()
}

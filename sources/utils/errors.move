module mobility_protocol::errors;

public fun relayer_status_update_not_required(): u64 {
    0
}

public fun not_whitelisted_relayer(): u64 {
    1
}

public fun amount_zero(): u64 {
    2
}

public fun already_attested(): u64 {
    3
}

public fun already_passed_attestation_threshold(): u64 {
    4
}

public fun already_used_one_time_witness(): u64 {
    5
}

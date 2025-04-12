#[test_only]
module mobility_protocol::mobility_protocol_tests;

const ENotImplemented: u64 = 0;

#[test]
fun test_mobility_protocol() {}

#[test, expected_failure(abort_code = ENotImplemented)]
fun test_mobility_protocol_fail() {
    abort ENotImplemented
}

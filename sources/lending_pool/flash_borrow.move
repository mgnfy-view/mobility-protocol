module mobility_protocol::flash_borrow;

use mobility_protocol::create_lending_pools;
use mobility_protocol::errors;
use sui::coin;
use sui::event;

// ===== Global storage structs =====

/// Hot potato received at the start of a flash borrow session that is
/// destroyed only when the amount is repaid in full.
public struct FlashBorrow {
    lending_pool_wrapper_id: object::ID,
    amount: u64,
}

// ===== Events =====

/// Emitted when the flash borrow amount is repaid.
public struct FlashBorrowed has copy, drop {
    lending_pool_wrapper_id: object::ID,
    user: address,
    amount: u64,
}

// ===== Public functions =====

/// Starts a flash borrow session by sending the quoted coins to the given user address from
/// the given lending pool, and also transferring the flash borrow hot potato.
///
/// Args:
///
/// lending_pool_wrapper:   The lending pool to flash borrow from.
/// amount:                 The amount ot flash borrow.
/// receiver:               The recipient of the flash borrowed coins.
/// ctx:                    The transaction context.
public fun start_flash_borrow_session<CoinType>(
    lending_pool_wrapper: &mut create_lending_pools::LendingPoolWrapper<CoinType>,
    amount: u64,
    receiver: address,
    ctx: &mut TxContext,
): FlashBorrow {
    lending_pool_wrapper.withdraw_coins_from_lending_pool(
        amount,
        receiver,
        ctx,
    );

    let flash_borrow = FlashBorrow {
        lending_pool_wrapper_id: lending_pool_wrapper.get_lending_pool_id(),
        amount,
    };

    flash_borrow
}

/// End a flash borrow session by returning the borrowed amount and destroying the hot
/// potato.
///
/// Args:
///
/// lending_pool_wrapper:   The lending pool to flash borrow from.
/// flash_borrow:           The flash borrow hot potato.
/// coin:                   The coin object to repay the flash borrow with.
/// ctx:                    The transaction context.
public fun end_flash_borrow_session<CoinType>(
    lending_pool_wrapper: &mut create_lending_pools::LendingPoolWrapper<CoinType>,
    flash_borrow: FlashBorrow,
    coin: coin::Coin<CoinType>,
    ctx: &mut TxContext,
) {
    let FlashBorrow { lending_pool_wrapper_id, amount } = flash_borrow;

    assert!(
        lending_pool_wrapper.get_lending_pool_id() == lending_pool_wrapper_id,
        errors::invalid_lending_pool(),
    );
    assert!(coin.value() == amount, errors::flash_borrow_failed());

    lending_pool_wrapper.transfer_coins_to_lending_pool(coin);

    event::emit(FlashBorrowed {
        lending_pool_wrapper_id,
        user: ctx.sender(),
        amount,
    });
}

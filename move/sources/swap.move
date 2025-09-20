module suiworld::swap {
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use suiworld::token::{Self, SWT, SwapPool};

    // Swap events
    public struct SwapExecuted has copy, drop {
        user: address,
        sui_amount: u64,
        swt_amount: u64,
        is_sui_to_swt: bool,
        timestamp: u64,
    }

    public struct LiquidityAdded has copy, drop {
        provider: address,
        sui_amount: u64,
        swt_amount: u64,
    }

    public struct LiquidityRemoved has copy, drop {
        provider: address,
        sui_amount: u64,
        swt_amount: u64,
    }

    // Constants
    const SWAP_FEE_BPS: u64 = 30; // 0.3% fee in basis points
    const BPS_SCALE: u64 = 10000;
    const MIN_LIQUIDITY: u64 = 1000;

    // Error codes
    const EInsufficientLiquidity: u64 = 1;
    const EInsufficientInput: u64 = 2;
    const ESlippageExceeded: u64 = 3;
    const EZeroAmount: u64 = 4;
    const EPoolNotInitialized: u64 = 5;

    // Swap SUI to SWT
    public fun swap_sui_to_swt(
        pool: &mut SwapPool,
        sui_coin: Coin<SUI>,
        min_swt_out: u64,
        ctx: &mut TxContext
    ): Coin<SWT> {
        let user = tx_context::sender(ctx);
        let sui_amount = coin::value(&sui_coin);

        assert!(sui_amount > 0, EZeroAmount);

        // Get pool reserves
        let sui_reserve = get_sui_reserve(pool);
        let swt_reserve = get_swt_reserve(pool);

        assert!(sui_reserve > 0 && swt_reserve > 0, EPoolNotInitialized);

        // Calculate output amount using constant product formula
        let swt_out = calculate_output_amount(
            sui_amount,
            sui_reserve,
            swt_reserve
        );

        // Check slippage
        assert!(swt_out >= min_swt_out, ESlippageExceeded);

        // Add SUI to pool
        let sui_balance = coin::into_balance(sui_coin);
        add_sui_to_pool(pool, sui_balance);

        // Remove SWT from pool and return to caller
        let swt_balance = remove_swt_from_pool(pool, swt_out);
        let swt_coin = coin::from_balance(swt_balance, ctx);

        // Emit event
        event::emit(SwapExecuted {
            user,
            sui_amount,
            swt_amount: swt_out,
            is_sui_to_swt: true,
            timestamp: tx_context::epoch(ctx),
        });

        swt_coin
    }

    // Swap SWT to SUI
    public fun swap_swt_to_sui(
        pool: &mut SwapPool,
        swt_coin: Coin<SWT>,
        min_sui_out: u64,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let user = tx_context::sender(ctx);
        let swt_amount = coin::value(&swt_coin);

        assert!(swt_amount > 0, EZeroAmount);

        // Get pool reserves
        let sui_reserve = get_sui_reserve(pool);
        let swt_reserve = get_swt_reserve(pool);

        assert!(sui_reserve > 0 && swt_reserve > 0, EPoolNotInitialized);

        // Calculate output amount
        let sui_out = calculate_output_amount(
            swt_amount,
            swt_reserve,
            sui_reserve
        );

        // Check slippage
        assert!(sui_out >= min_sui_out, ESlippageExceeded);

        // Add SWT to pool
        let swt_balance = coin::into_balance(swt_coin);
        add_swt_to_pool(pool, swt_balance);

        // Remove SUI from pool and return to caller
        let sui_balance = remove_sui_from_pool(pool, sui_out);
        let sui_coin = coin::from_balance(sui_balance, ctx);

        // Emit event
        event::emit(SwapExecuted {
            user,
            sui_amount: sui_out,
            swt_amount: swt_amount,
            is_sui_to_swt: false,
            timestamp: tx_context::epoch(ctx),
        });

        sui_coin
    }

    // Add liquidity to the pool
    public fun add_liquidity(
        pool: &mut SwapPool,
        sui_coin: Coin<SUI>,
        swt_coin: Coin<SWT>,
        ctx: &mut TxContext
    ) {
        let provider = tx_context::sender(ctx);
        let sui_amount = coin::value(&sui_coin);
        let swt_amount = coin::value(&swt_coin);

        assert!(sui_amount > MIN_LIQUIDITY, EInsufficientInput);
        assert!(swt_amount > MIN_LIQUIDITY, EInsufficientInput);

        // Add to pool
        let sui_balance = coin::into_balance(sui_coin);
        let swt_balance = coin::into_balance(swt_coin);

        add_sui_to_pool(pool, sui_balance);
        add_swt_to_pool(pool, swt_balance);

        // Emit event
        event::emit(LiquidityAdded {
            provider,
            sui_amount,
            swt_amount,
        });
    }

    // Remove liquidity from the pool (admin only for simplicity)
    public fun remove_liquidity(
        pool: &mut SwapPool,
        sui_amount: u64,
        swt_amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        // Check sufficient reserves
        assert!(get_sui_reserve(pool) >= sui_amount, EInsufficientLiquidity);
        assert!(get_swt_reserve(pool) >= swt_amount, EInsufficientLiquidity);

        // Remove from pool
        let sui_balance = remove_sui_from_pool(pool, sui_amount);
        let swt_balance = remove_swt_from_pool(pool, swt_amount);

        // Create coins and transfer
        let sui_coin = coin::from_balance(sui_balance, ctx);
        let swt_coin = coin::from_balance(swt_balance, ctx);

        transfer::public_transfer(sui_coin, recipient);
        transfer::public_transfer(swt_coin, recipient);

        // Emit event
        event::emit(LiquidityRemoved {
            provider: recipient,
            sui_amount,
            swt_amount,
        });
    }

    // Calculate output amount using constant product formula with fee
    fun calculate_output_amount(
        input_amount: u64,
        input_reserve: u64,
        output_reserve: u64
    ): u64 {
        // Apply fee
        let input_with_fee = input_amount * (BPS_SCALE - SWAP_FEE_BPS);

        // x * y = k formula
        // output = (output_reserve * input_with_fee) / (input_reserve * BPS_SCALE + input_with_fee)
        let numerator = output_reserve * input_with_fee;
        let denominator = input_reserve * BPS_SCALE + input_with_fee;

        numerator / denominator
    }

    // Get quote for swap
    public fun get_swap_quote(
        pool: &SwapPool,
        input_amount: u64,
        is_sui_to_swt: bool
    ): u64 {
        let sui_reserve = get_sui_reserve(pool);
        let swt_reserve = get_swt_reserve(pool);

        if (is_sui_to_swt) {
            calculate_output_amount(input_amount, sui_reserve, swt_reserve)
        } else {
            calculate_output_amount(input_amount, swt_reserve, sui_reserve)
        }
    }

    // Pool helper functions (these would normally be in the token module)
    public fun get_sui_reserve(pool: &SwapPool): u64 {
        balance::value(token::get_sui_balance(pool))
    }

    public fun get_swt_reserve(pool: &SwapPool): u64 {
        balance::value(token::get_swt_balance(pool))
    }

    fun add_sui_to_pool(pool: &mut SwapPool, balance: Balance<SUI>) {
        balance::join(token::get_mut_sui_balance(pool), balance);
    }

    fun add_swt_to_pool(pool: &mut SwapPool, balance: Balance<SWT>) {
        balance::join(token::get_mut_swt_balance(pool), balance);
    }

    fun remove_sui_from_pool(pool: &mut SwapPool, amount: u64): Balance<SUI> {
        balance::split(token::get_mut_sui_balance(pool), amount)
    }

    fun remove_swt_from_pool(pool: &mut SwapPool, amount: u64): Balance<SWT> {
        balance::split(token::get_mut_swt_balance(pool), amount)
    }

    // Get pool price
    public fun get_price_sui_per_swt(pool: &SwapPool): u64 {
        let sui_reserve = get_sui_reserve(pool);
        let swt_reserve = get_swt_reserve(pool);

        if (swt_reserve == 0) {
            0
        } else {
            (sui_reserve * BPS_SCALE) / swt_reserve
        }
    }

    public fun get_price_swt_per_sui(pool: &SwapPool): u64 {
        let sui_reserve = get_sui_reserve(pool);
        let swt_reserve = get_swt_reserve(pool);

        if (sui_reserve == 0) {
            0
        } else {
            (swt_reserve * BPS_SCALE) / sui_reserve
        }
    }
}

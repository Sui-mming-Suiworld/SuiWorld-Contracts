module suiworld::token {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::event;

    // One-time witness for token initialization
    public struct TOKEN has drop {}

    // SWT Token Type
    public struct SWT has drop {}

    // Treasury for managing minted tokens
    public struct Treasury has key {
        id: UID,
        balance: Balance<SWT>,
        total_minted: u64,
    }

    // Pool for swap operations
    public struct SwapPool has key {
        id: UID,
        swt_balance: Balance<SWT>,
        sui_balance: Balance<sui::sui::SUI>,
    }

    // Events
    public struct TokenMinted has copy, drop {
        amount: u64,
        recipient: address,
    }

    public struct TokenBurned has copy, drop {
        amount: u64,
        from: address,
    }

    // Constants
    const TOTAL_SUPPLY: u64 = 100_000_000_000_000; // 100M SWT with 6 decimals
    const TREASURY_PERCENTAGE: u64 = 30;
    const POOL_PERCENTAGE: u64 = 70;
    const DECIMALS: u8 = 6;

    // Error codes
    const EInsufficientBalance: u64 = 1;

    // Initialize the SWT token
    fun init(_witness: TOKEN, ctx: &mut TxContext) {
        let swt_witness = SWT {};
        let (mut treasury_cap, metadata) = coin::create_currency(
            swt_witness,
            DECIMALS,
            b"SWT",
            b"SuiWorld Token",
            b"The native token of SuiWorld platform",
            option::none(),
            ctx
        );

        // Mint total supply
        let total_supply_coin = coin::mint(&mut treasury_cap, TOTAL_SUPPLY, ctx);
        let mut total_balance = coin::into_balance(total_supply_coin);

        // Calculate treasury and pool amounts
        let treasury_amount = (TOTAL_SUPPLY * TREASURY_PERCENTAGE) / 100;
        let _pool_amount = (TOTAL_SUPPLY * POOL_PERCENTAGE) / 100;

        // Split balances for treasury and pool
        let treasury_balance = balance::split(&mut total_balance, treasury_amount);
        let pool_balance = total_balance;

        // Create treasury
        let treasury = Treasury {
            id: object::new(ctx),
            balance: treasury_balance,
            total_minted: TOTAL_SUPPLY,
        };

        // Create swap pool
        let swap_pool = SwapPool {
            id: object::new(ctx),
            swt_balance: pool_balance,
            sui_balance: balance::zero(),
        };

        // Share objects
        transfer::share_object(treasury);
        transfer::share_object(swap_pool);

        // Freeze metadata
        transfer::public_freeze_object(metadata);

        // Transfer treasury cap to deployer
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        // Simplified test init without currency creation
        // Just create empty treasury and pool for testing
        use sui::balance;

        // Create treasury with empty balance for testing
        let treasury = Treasury {
            id: object::new(ctx),
            balance: balance::zero<SWT>(),
            total_minted: 0,
        };

        // Create swap pool with empty balance for testing
        let swap_pool = SwapPool {
            id: object::new(ctx),
            swt_balance: balance::zero<SWT>(),
            sui_balance: balance::zero(),
        };

        transfer::share_object(treasury);
        transfer::share_object(swap_pool);
    }

    #[test_only]
    public fun test_mint_and_add_to_treasury(treasury: &mut Treasury, amount: u64, _ctx: &mut TxContext) {
        use sui::balance;
        use sui::test_utils;

        // Simply create test balance and add to treasury
        let test_balance = balance::create_for_testing<SWT>(amount);
        balance::join(&mut treasury.balance, test_balance);
        treasury.total_minted = treasury.total_minted + amount;
    }

    // Transfer SWT from treasury (for rewards)
    public fun transfer_from_treasury(
        treasury: &mut Treasury,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(balance::value(&treasury.balance) >= amount, EInsufficientBalance);

        let reward_balance = balance::split(&mut treasury.balance, amount);
        let reward_coin = coin::from_balance(reward_balance, ctx);

        transfer::public_transfer(reward_coin, recipient);

        event::emit(TokenMinted {
            amount,
            recipient,
        });
    }

    // Burn tokens (for slashing)
    public fun burn_tokens(
        treasury: &mut Treasury,
        coin: Coin<SWT>,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&coin);
        let sender = tx_context::sender(ctx);

        // Add burned tokens back to treasury
        let burned_balance = coin::into_balance(coin);
        balance::join(&mut treasury.balance, burned_balance);

        event::emit(TokenBurned {
            amount,
            from: sender,
        });
    }

    // Check if user has minimum balance for actions
    public fun check_minimum_balance(coin: &Coin<SWT>, minimum: u64): bool {
        coin::value(coin) >= minimum
    }

    // Get treasury balance
    public fun get_treasury_balance(treasury: &Treasury): u64 {
        balance::value(&treasury.balance)
    }

    // Get total minted amount
    public fun get_total_minted(treasury: &Treasury): u64 {
        treasury.total_minted
    }

    // SwapPool accessor functions for swap module
    public fun get_sui_balance(pool: &SwapPool): &Balance<sui::sui::SUI> {
        &pool.sui_balance
    }

    public fun get_swt_balance(pool: &SwapPool): &Balance<SWT> {
        &pool.swt_balance
    }

    public fun get_mut_sui_balance(pool: &mut SwapPool): &mut Balance<sui::sui::SUI> {
        &mut pool.sui_balance
    }

    public fun get_mut_swt_balance(pool: &mut SwapPool): &mut Balance<SWT> {
        &mut pool.swt_balance
    }
}

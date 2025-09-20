module suiworld::token {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::event;


    // One-time witness for token initialization and coin type
    public struct TOKEN has drop {}

    // Type alias for better code readability
    // Other modules will import TOKEN as SWT
    // Example: use suiworld::token::{TOKEN as SWT};

    // Admin capability for treasury management
    public struct AdminCap has key, store {
        id: UID,
    }

    // Treasury for managing minted tokens
    public struct Treasury has key {
        id: UID,
        balance: Balance<TOKEN>,
        total_minted: u64,
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
    const DECIMALS: u8 = 6;

    // Error codes
    const EInsufficientBalance: u64 = 1;

    // Initialize the SWT token
    fun init(witness: TOKEN, ctx: &mut TxContext) {
        // Use the TOKEN witness directly
        let (mut treasury_cap, metadata) = coin::create_currency(
            witness,
            DECIMALS,
            b"SWT",
            b"SuiWorld Token",
            b"The native token of SuiWorld platform",
            option::none(),
            ctx
        );

        // Mint total supply
        let total_supply_coin = coin::mint(&mut treasury_cap, TOTAL_SUPPLY, ctx);
        let total_balance = coin::into_balance(total_supply_coin);

        // All initial supply goes to treasury
        // External DEX liquidity will be added separately
        let treasury = Treasury {
            id: object::new(ctx),
            balance: total_balance,
            total_minted: TOTAL_SUPPLY,
        };

        // Create admin capability for deployer
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        // Share treasury
        transfer::share_object(treasury);

        // Freeze metadata
        transfer::public_freeze_object(metadata);

        // Transfer treasury cap and admin cap to deployer
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_transfer(admin_cap, tx_context::sender(ctx));
    }


    // Transfer SWT from treasury (admin only)
    public fun transfer_from_treasury(
        treasury: &mut Treasury,
        _admin: &AdminCap,  // Only admin can call this
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

    // Internal transfer for rewards module (package function)
    public(package) fun transfer_from_treasury_internal(
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
        coin: Coin<TOKEN>,
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

    // Return tokens to treasury (used for penalties and slashing)
    public fun return_tokens_to_treasury(
        treasury: &mut Treasury,
        returned_balance: Balance<TOKEN>
    ) {
        let amount = balance::value(&returned_balance);

        // Add tokens back to treasury for redistribution
        balance::join(&mut treasury.balance, returned_balance);

        event::emit(TokenBurned {
            amount,
            from: @0x0, // System return to treasury
        });
    }

    // Check if user has minimum balance for actions
    public fun check_minimum_balance(coin: &Coin<TOKEN>, minimum: u64): bool {
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

}

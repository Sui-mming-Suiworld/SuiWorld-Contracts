module suiworld::token {
    use sui::coin::{Self, Coin, TreasuryCap};
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

    // Treasury for managing minted tokens with NTT compatibility
    public struct Treasury has key {
        id: UID,
        balance: Balance<TOKEN>,
        total_minted: u64,
        // Track cross-chain operations for NTT
        total_locked: u64,
        total_burned: u64,
    }

    // NTT Manager capability for Wormhole integration
    public struct NTTManagerCap has key, store {
        id: UID,
    }


    // Events with NTT compatibility
    public struct TokenMinted has copy, drop {
        amount: u64,
        recipient: address,
        chain_id: option::Option<u16>, // Wormhole chain ID for cross-chain mints
    }

    public struct TokenBurned has copy, drop {
        amount: u64,
        from: address,
        chain_id: option::Option<u16>, // Wormhole chain ID for cross-chain burns
    }

    public struct TokenLocked has copy, drop {
        amount: u64,
        from: address,
        destination_chain: u16,
    }

    public struct TokenUnlocked has copy, drop {
        amount: u64,
        recipient: address,
        source_chain: u16,
    }

    // Constants
    const TOTAL_SUPPLY: u64 = 100_000_000_000_000; // 100M SWT with 6 decimals
    const DECIMALS: u8 = 6;

    // Error codes
    const EInsufficientBalance: u64 = 1;
    const EUnauthorized: u64 = 2;
    const EInvalidAmount: u64 = 3;

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

        // All initial supply goes to treasury with NTT tracking
        let treasury = Treasury {
            id: object::new(ctx),
            balance: total_balance,
            total_minted: TOTAL_SUPPLY,
            total_locked: 0,
            total_burned: 0,
        };

        // Create admin capability for deployer
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        // Create NTT manager capability for Wormhole integration
        let ntt_manager_cap = NTTManagerCap {
            id: object::new(ctx),
        };

        // Share treasury
        transfer::share_object(treasury);

        // Freeze metadata
        transfer::public_freeze_object(metadata);

        // Transfer treasury cap and admin cap to deployer
        // Treasury cap will be transferred to NTT manager for burn-and-mint mode
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_transfer(admin_cap, tx_context::sender(ctx));
        transfer::public_transfer(ntt_manager_cap, tx_context::sender(ctx));
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
            chain_id: option::none(),
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
            chain_id: option::none(),
        });
    }

    // === NTT Functions for Cross-Chain Operations ===

    // Lock tokens for hub-and-spoke mode (called by NTT manager)
    public fun lock_for_transfer(
        treasury: &mut Treasury,
        coin: Coin<TOKEN>,
        destination_chain: u16,
        ctx: &mut TxContext
    ): u64 {
        let amount = coin::value(&coin);
        let sender = tx_context::sender(ctx);

        // Add locked tokens to treasury
        let locked_balance = coin::into_balance(coin);
        balance::join(&mut treasury.balance, locked_balance);

        // Update locked amount
        treasury.total_locked = treasury.total_locked + amount;

        event::emit(TokenLocked {
            amount,
            from: sender,
            destination_chain,
        });

        amount
    }

    // Unlock tokens for hub-and-spoke mode (called by NTT manager)
    public fun unlock_from_transfer(
        treasury: &mut Treasury,
        _ntt_cap: &NTTManagerCap,
        amount: u64,
        recipient: address,
        source_chain: u16,
        ctx: &mut TxContext
    ) {
        assert!(balance::value(&treasury.balance) >= amount, EInsufficientBalance);
        assert!(treasury.total_locked >= amount, EInsufficientBalance);

        let unlock_balance = balance::split(&mut treasury.balance, amount);
        let unlock_coin = coin::from_balance(unlock_balance, ctx);

        // Update locked amount
        treasury.total_locked = treasury.total_locked - amount;

        transfer::public_transfer(unlock_coin, recipient);

        event::emit(TokenUnlocked {
            amount,
            recipient,
            source_chain,
        });
    }

    // Burn tokens for burn-and-mint mode (called by NTT manager)
    public fun burn_for_transfer(
        treasury: &mut Treasury,
        coin: Coin<TOKEN>,
        destination_chain: u16,
        ctx: &mut TxContext
    ): u64 {
        let amount = coin::value(&coin);
        let sender = tx_context::sender(ctx);

        // Add to treasury and track as burned
        let burned_balance = coin::into_balance(coin);
        balance::join(&mut treasury.balance, burned_balance);

        // Update burned amount
        treasury.total_burned = treasury.total_burned + amount;

        event::emit(TokenBurned {
            amount,
            from: sender,
            chain_id: option::some(destination_chain),
        });

        amount
    }

    // Mint tokens from cross-chain transfer (called by NTT manager)
    // Requires treasury cap to be owned by NTT manager
    public fun mint_from_transfer(
        treasury_cap: &mut TreasuryCap<TOKEN>,
        amount: u64,
        recipient: address,
        source_chain: u16,
        ctx: &mut TxContext
    ) {
        // Mint new tokens for cross-chain transfer
        let minted_coin = coin::mint(treasury_cap, amount, ctx);

        transfer::public_transfer(minted_coin, recipient);

        event::emit(TokenMinted {
            amount,
            recipient,
            chain_id: option::some(source_chain),
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
            chain_id: option::none(),
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
            chain_id: option::none(),
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

    // Get total locked amount (for NTT hub-and-spoke)
    public fun get_total_locked(treasury: &Treasury): u64 {
        treasury.total_locked
    }

    // Get total burned amount (for NTT burn-and-mint)
    public fun get_total_burned(treasury: &Treasury): u64 {
        treasury.total_burned
    }

    // Get circulating supply (for NTT accounting)
    public fun get_circulating_supply(treasury: &Treasury): u64 {
        treasury.total_minted - treasury.total_burned - balance::value(&treasury.balance)
    }

}

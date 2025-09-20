module suiworld::slashing {
    use sui::event;
    use sui::table::{Self, Table};
    use suiworld::token::{Self, Treasury, TOKEN as SWT};
    use sui::coin::{Self, Coin};

    // Slashing tracking system
    public struct SlashingSystem has key {
        id: UID,
        total_slashed: u64,
        user_penalties: Table<address, UserPenaltyInfo>,
        pending_slashes: vector<SlashEntry>,
    }

    public struct UserPenaltyInfo has store {
        total_slashed: u64,
        scam_messages_count: u64,
        warnings_count: u64,
        is_blacklisted: bool,
        last_slash_timestamp: u64,
    }

    public struct SlashEntry has store, copy, drop {
        user: address,
        amount: u64,
        reason: vector<u8>,
        message_id: ID,
        created_at: u64,
    }

    // Events
    public struct UserSlashed has copy, drop {
        user: address,
        amount: u64,
        reason: vector<u8>,
        timestamp: u64,
    }

    public struct UserWarned has copy, drop {
        user: address,
        warning_count: u64,
        reason: vector<u8>,
    }

    public struct UserBlacklisted has copy, drop {
        user: address,
        total_violations: u64,
        timestamp: u64,
    }

    // Constants
    const SCAM_MESSAGE_PENALTY: u64 = 200_000_000; // 200 SWT
    const WARNING_THRESHOLD: u64 = 3;
    const BLACKLIST_THRESHOLD: u64 = 5;

    // Error codes
    const EInsufficientBalance: u64 = 1;
    const EUserBlacklisted: u64 = 2;
    const EInvalidAmount: u64 = 4;

    // Initialize slashing system
    fun init(ctx: &mut TxContext) {
        let slashing_system = SlashingSystem {
            id: object::new(ctx),
            total_slashed: 0,
            user_penalties: table::new(ctx),
            pending_slashes: vector::empty(),
        };

        transfer::share_object(slashing_system);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    // Slash tokens for scam message
    public fun slash_for_scam(
        slashing_system: &mut SlashingSystem,
        treasury: &mut Treasury,
        user_coin: Coin<SWT>,
        user: address,
        message_id: ID,
        ctx: &mut TxContext
    ) {
        // Check if user is blacklisted
        if (is_user_blacklisted(slashing_system, user)) {
            abort EUserBlacklisted
        };

        let amount = SCAM_MESSAGE_PENALTY;
        let coin_value = coin::value(&user_coin);

        // Check sufficient balance
        assert!(coin_value >= amount, EInsufficientBalance);

        // Update user penalty info
        if (!table::contains(&slashing_system.user_penalties, user)) {
            let info = UserPenaltyInfo {
                total_slashed: 0,
                scam_messages_count: 0,
                warnings_count: 0,
                is_blacklisted: false,
                last_slash_timestamp: 0,
            };
            table::add(&mut slashing_system.user_penalties, user, info);
        };

        let user_info = table::borrow_mut(&mut slashing_system.user_penalties, user);
        user_info.total_slashed = user_info.total_slashed + amount;
        user_info.scam_messages_count = user_info.scam_messages_count + 1;
        user_info.last_slash_timestamp = tx_context::epoch(ctx);

        // Check if user should be warned or blacklisted
        if (user_info.scam_messages_count >= BLACKLIST_THRESHOLD) {
            user_info.is_blacklisted = true;
            event::emit(UserBlacklisted {
                user,
                total_violations: user_info.scam_messages_count,
                timestamp: tx_context::epoch(ctx),
            });
        } else if (user_info.scam_messages_count >= WARNING_THRESHOLD) {
            user_info.warnings_count = user_info.warnings_count + 1;
            event::emit(UserWarned {
                user,
                warning_count: user_info.warnings_count,
                reason: b"Multiple scam messages detected",
            });
        };

        // Burn the slashed tokens (send back to treasury)
        token::burn_tokens(treasury, user_coin, ctx);

        // Update total slashed
        slashing_system.total_slashed = slashing_system.total_slashed + amount;

        // Record slash entry
        let slash_entry = SlashEntry {
            user,
            amount,
            reason: b"Scam message penalty",
            message_id,
            created_at: tx_context::epoch(ctx),
        };
        vector::push_back(&mut slashing_system.pending_slashes, slash_entry);

        // Emit event
        event::emit(UserSlashed {
            user,
            amount,
            reason: b"Scam message penalty",
            timestamp: tx_context::epoch(ctx),
        });
    }

    // Custom slash function for other violations
    public fun custom_slash(
        slashing_system: &mut SlashingSystem,
        treasury: &mut Treasury,
        user_coin: Coin<SWT>,
        user: address,
        amount: u64,
        reason: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(amount > 0, EInvalidAmount);

        // Check if user is blacklisted
        if (is_user_blacklisted(slashing_system, user)) {
            abort EUserBlacklisted
        };

        let coin_value = coin::value(&user_coin);

        // Check sufficient balance
        assert!(coin_value >= amount, EInsufficientBalance);

        // Update user penalty info
        if (!table::contains(&slashing_system.user_penalties, user)) {
            let info = UserPenaltyInfo {
                total_slashed: 0,
                scam_messages_count: 0,
                warnings_count: 0,
                is_blacklisted: false,
                last_slash_timestamp: 0,
            };
            table::add(&mut slashing_system.user_penalties, user, info);
        };

        let user_info = table::borrow_mut(&mut slashing_system.user_penalties, user);
        user_info.total_slashed = user_info.total_slashed + amount;
        user_info.last_slash_timestamp = tx_context::epoch(ctx);

        // Burn the slashed tokens
        token::burn_tokens(treasury, user_coin, ctx);

        // Update total slashed
        slashing_system.total_slashed = slashing_system.total_slashed + amount;

        // Emit event
        event::emit(UserSlashed {
            user,
            amount,
            reason,
            timestamp: tx_context::epoch(ctx),
        });
    }

    // Issue warning to user
    public fun issue_warning(
        slashing_system: &mut SlashingSystem,
        user: address,
        reason: vector<u8>,
        _ctx: &mut TxContext
    ) {
        if (!table::contains(&slashing_system.user_penalties, user)) {
            let info = UserPenaltyInfo {
                total_slashed: 0,
                scam_messages_count: 0,
                warnings_count: 0,
                is_blacklisted: false,
                last_slash_timestamp: 0,
            };
            table::add(&mut slashing_system.user_penalties, user, info);
        };

        let user_info = table::borrow_mut(&mut slashing_system.user_penalties, user);
        user_info.warnings_count = user_info.warnings_count + 1;

        event::emit(UserWarned {
            user,
            warning_count: user_info.warnings_count,
            reason,
        });
    }

    // Remove user from blacklist (admin function)
    public fun remove_from_blacklist(
        slashing_system: &mut SlashingSystem,
        user: address,
        _ctx: &mut TxContext
    ) {
        if (table::contains(&slashing_system.user_penalties, user)) {
            let user_info = table::borrow_mut(&mut slashing_system.user_penalties, user);
            user_info.is_blacklisted = false;
            user_info.warnings_count = 0; // Reset warnings
        }
    }

    // Check if user is blacklisted
    public fun is_user_blacklisted(slashing_system: &SlashingSystem, user: address): bool {
        if (!table::contains(&slashing_system.user_penalties, user)) {
            return false
        };

        let user_info = table::borrow(&slashing_system.user_penalties, user);
        user_info.is_blacklisted
    }

    // Get user penalty info
    public fun get_user_penalty_info(
        slashing_system: &SlashingSystem,
        user: address
    ): (u64, u64, u64, bool) {
        if (!table::contains(&slashing_system.user_penalties, user)) {
            return (0, 0, 0, false)
        };

        let info = table::borrow(&slashing_system.user_penalties, user);
        (
            info.total_slashed,
            info.scam_messages_count,
            info.warnings_count,
            info.is_blacklisted
        )
    }

    // Get total slashed amount
    public fun get_total_slashed(slashing_system: &SlashingSystem): u64 {
        slashing_system.total_slashed
    }

    // Get pending slashes count
    public fun get_pending_slashes_count(slashing_system: &SlashingSystem): u64 {
        vector::length(&slashing_system.pending_slashes)
    }

    // Clear old pending slashes (admin maintenance)
    public fun clear_old_pending_slashes(
        slashing_system: &mut SlashingSystem,
        max_to_clear: u64,
        _ctx: &mut TxContext
    ) {
        let mut cleared = 0;
        while (cleared < max_to_clear && !vector::is_empty(&slashing_system.pending_slashes)) {
            vector::pop_back(&mut slashing_system.pending_slashes);
            cleared = cleared + 1;
        };
    }
}

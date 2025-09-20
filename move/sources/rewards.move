module suiworld::rewards {
    use sui::event;
    use sui::table::{Self, Table};
    use suiworld::token::{Self, Treasury};

    // Reward tracking
    public struct RewardSystem has key {
        id: UID,
        total_rewards_distributed: u64,
        user_rewards: Table<address, UserRewardInfo>,
        pending_airdrops: vector<AirdropEntry>,
    }

    public struct UserRewardInfo has store {
        total_earned: u64,
        hyped_messages_count: u64,
        manager_rewards: u64,
        airdrop_received: u64,
        last_reward_timestamp: u64,
    }

    public struct AirdropEntry has store, copy, drop {
        recipient: address,
        amount: u64,
        reason: vector<u8>,
        scheduled_at: u64,
    }

    // Events
    public struct RewardDistributed has copy, drop {
        recipient: address,
        amount: u64,
        reward_type: u8, // 0: hype, 1: manager, 2: airdrop
        timestamp: u64,
    }

    public struct AirdropScheduled has copy, drop {
        recipients: vector<address>,
        total_amount: u64,
        scheduled_at: u64,
    }

    // Constants
    const REWARD_TYPE_HYPE: u8 = 0;
    const REWARD_TYPE_MANAGER: u8 = 1;
    const REWARD_TYPE_AIRDROP: u8 = 2;

    const WEEKLY_AIRDROP_AMOUNT: u64 = 1000_000_000; // 1000 SWT for random distribution

    // Error codes
    const EInsufficientTreasuryBalance: u64 = 1;

    // Initialize reward system
    fun init(ctx: &mut TxContext) {
        let reward_system = RewardSystem {
            id: object::new(ctx),
            total_rewards_distributed: 0,
            user_rewards: table::new(ctx),
            pending_airdrops: vector::empty(),
        };

        transfer::share_object(reward_system);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    // Distribute reward for hyped message
    public fun distribute_hype_reward(
        reward_system: &mut RewardSystem,
        treasury: &mut Treasury,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Check treasury balance
        assert!(
            token::get_treasury_balance(treasury) >= amount,
            EInsufficientTreasuryBalance
        );

        // Update user reward info
        if (!table::contains(&reward_system.user_rewards, recipient)) {
            let info = UserRewardInfo {
                total_earned: 0,
                hyped_messages_count: 0,
                manager_rewards: 0,
                airdrop_received: 0,
                last_reward_timestamp: 0,
            };
            table::add(&mut reward_system.user_rewards, recipient, info);
        };

        let user_info = table::borrow_mut(&mut reward_system.user_rewards, recipient);
        user_info.total_earned = user_info.total_earned + amount;
        user_info.hyped_messages_count = user_info.hyped_messages_count + 1;
        user_info.last_reward_timestamp = tx_context::epoch(ctx);

        // Transfer reward
        token::transfer_from_treasury(treasury, amount, recipient, ctx);

        // Update total distributed
        reward_system.total_rewards_distributed =
            reward_system.total_rewards_distributed + amount;

        // Emit event
        event::emit(RewardDistributed {
            recipient,
            amount,
            reward_type: REWARD_TYPE_HYPE,
            timestamp: tx_context::epoch(ctx),
        });
    }

    // Distribute reward for manager voting
    public fun distribute_manager_reward(
        reward_system: &mut RewardSystem,
        treasury: &mut Treasury,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Check treasury balance
        assert!(
            token::get_treasury_balance(treasury) >= amount,
            EInsufficientTreasuryBalance
        );

        // Update user reward info
        if (!table::contains(&reward_system.user_rewards, recipient)) {
            let info = UserRewardInfo {
                total_earned: 0,
                hyped_messages_count: 0,
                manager_rewards: 0,
                airdrop_received: 0,
                last_reward_timestamp: 0,
            };
            table::add(&mut reward_system.user_rewards, recipient, info);
        };

        let user_info = table::borrow_mut(&mut reward_system.user_rewards, recipient);
        user_info.manager_rewards = user_info.manager_rewards + amount;
        user_info.total_earned = user_info.total_earned + amount;
        user_info.last_reward_timestamp = tx_context::epoch(ctx);

        // Transfer reward
        token::transfer_from_treasury(treasury, amount, recipient, ctx);

        // Update total distributed
        reward_system.total_rewards_distributed =
            reward_system.total_rewards_distributed + amount;

        // Emit event
        event::emit(RewardDistributed {
            recipient,
            amount,
            reward_type: REWARD_TYPE_MANAGER,
            timestamp: tx_context::epoch(ctx),
        });
    }

    // Schedule random airdrop for cooking message creators
    public fun schedule_random_airdrop(
        reward_system: &mut RewardSystem,
        recipients: vector<address>,
        ctx: &mut TxContext
    ) {
        let total_recipients = vector::length(&recipients);
        if (total_recipients == 0) {
            return
        };

        let amount_per_recipient = WEEKLY_AIRDROP_AMOUNT / total_recipients;
        let scheduled_at = tx_context::epoch(ctx);

        let mut i = 0;
        while (i < total_recipients) {
            let recipient = *vector::borrow(&recipients, i);
            let entry = AirdropEntry {
                recipient,
                amount: amount_per_recipient,
                reason: b"Weekly cooking message airdrop",
                scheduled_at,
            };
            vector::push_back(&mut reward_system.pending_airdrops, entry);
            i = i + 1;
        };

        // Emit event
        event::emit(AirdropScheduled {
            recipients,
            total_amount: WEEKLY_AIRDROP_AMOUNT,
            scheduled_at,
        });
    }

    // Execute pending airdrops
    public fun execute_airdrops(
        reward_system: &mut RewardSystem,
        treasury: &mut Treasury,
        max_airdrops: u64,
        ctx: &mut TxContext
    ) {
        let mut executed = 0;

        while (executed < max_airdrops && !vector::is_empty(&reward_system.pending_airdrops)) {
            let airdrop = vector::pop_back(&mut reward_system.pending_airdrops);

            // Check treasury balance
            if (token::get_treasury_balance(treasury) < airdrop.amount) {
                // Put it back if not enough balance
                vector::push_back(&mut reward_system.pending_airdrops, airdrop);
                break
            };

            // Update user reward info
            if (!table::contains(&reward_system.user_rewards, airdrop.recipient)) {
                let info = UserRewardInfo {
                    total_earned: 0,
                    hyped_messages_count: 0,
                    manager_rewards: 0,
                    airdrop_received: 0,
                    last_reward_timestamp: 0,
                };
                table::add(&mut reward_system.user_rewards, airdrop.recipient, info);
            };

            let user_info = table::borrow_mut(&mut reward_system.user_rewards, airdrop.recipient);
            user_info.airdrop_received = user_info.airdrop_received + airdrop.amount;
            user_info.total_earned = user_info.total_earned + airdrop.amount;
            user_info.last_reward_timestamp = tx_context::epoch(ctx);

            // Transfer airdrop
            token::transfer_from_treasury(treasury, airdrop.amount, airdrop.recipient, ctx);

            // Update total distributed
            reward_system.total_rewards_distributed =
                reward_system.total_rewards_distributed + airdrop.amount;

            // Emit event
            event::emit(RewardDistributed {
                recipient: airdrop.recipient,
                amount: airdrop.amount,
                reward_type: REWARD_TYPE_AIRDROP,
                timestamp: tx_context::epoch(ctx),
            });

            executed = executed + 1;
        };
    }

    // Get user reward info
    public fun get_user_reward_info(
        reward_system: &RewardSystem,
        user: address
    ): (u64, u64, u64, u64) {
        if (!table::contains(&reward_system.user_rewards, user)) {
            return (0, 0, 0, 0)
        };

        let info = table::borrow(&reward_system.user_rewards, user);
        (
            info.total_earned,
            info.hyped_messages_count,
            info.manager_rewards,
            info.airdrop_received
        )
    }

    // Get total rewards distributed
    public fun get_total_rewards_distributed(reward_system: &RewardSystem): u64 {
        reward_system.total_rewards_distributed
    }

    // Get pending airdrops count
    public fun get_pending_airdrops_count(reward_system: &RewardSystem): u64 {
        vector::length(&reward_system.pending_airdrops)
    }
}

module suiworld::rewards {
    use sui::event;
    use sui::table::{Self, Table};
    use suiworld::token::{Self, Treasury};

    // Reward tracking
    public struct RewardSystem has key {
        id: UID,
        total_rewards_distributed: u64,
        user_rewards: Table<address, UserRewardInfo>,
    }

    public struct UserRewardInfo has store {
        total_earned: u64,
        hyped_messages_count: u64,
        manager_rewards: u64,
        last_reward_timestamp: u64,
    }

    // Events
    public struct RewardDistributed has copy, drop {
        recipient: address,
        amount: u64,
        reward_type: u8, // 0: hype, 1: manager
        timestamp: u64,
    }

    // Constants
    const REWARD_TYPE_HYPE: u8 = 0;
    const REWARD_TYPE_MANAGER: u8 = 1;

    // Error codes
    const EInsufficientTreasuryBalance: u64 = 1;

    // Initialize reward system
    fun init(ctx: &mut TxContext) {
        let reward_system = RewardSystem {
            id: object::new(ctx),
            total_rewards_distributed: 0,
            user_rewards: table::new(ctx),
        };

        transfer::share_object(reward_system);
    }

    // Distribute reward for hyped message (only callable by vote module)
    public(package) fun distribute_hype_reward(
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
                last_reward_timestamp: 0,
            };
            table::add(&mut reward_system.user_rewards, recipient, info);
        };

        let user_info = table::borrow_mut(&mut reward_system.user_rewards, recipient);
        user_info.total_earned = user_info.total_earned + amount;
        user_info.hyped_messages_count = user_info.hyped_messages_count + 1;
        user_info.last_reward_timestamp = tx_context::epoch(ctx);

        // Transfer reward using internal function (no AdminCap needed)
        token::transfer_from_treasury_internal(treasury, amount, recipient, ctx);

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

    // Distribute reward for manager voting (only callable by vote module)
    public(package) fun distribute_manager_reward(
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
                last_reward_timestamp: 0,
            };
            table::add(&mut reward_system.user_rewards, recipient, info);
        };

        let user_info = table::borrow_mut(&mut reward_system.user_rewards, recipient);
        user_info.manager_rewards = user_info.manager_rewards + amount;
        user_info.total_earned = user_info.total_earned + amount;
        user_info.last_reward_timestamp = tx_context::epoch(ctx);

        // Transfer reward using internal function (no AdminCap needed)
        token::transfer_from_treasury_internal(treasury, amount, recipient, ctx);

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

    // Get user reward info
    public fun get_user_reward_info(
        reward_system: &RewardSystem,
        user: address
    ): (u64, u64, u64) {
        if (!table::contains(&reward_system.user_rewards, user)) {
            return (0, 0, 0)
        };

        let info = table::borrow(&reward_system.user_rewards, user);
        (
            info.total_earned,
            info.hyped_messages_count,
            info.manager_rewards
        )
    }

    // Get total rewards distributed
    public fun get_total_rewards_distributed(reward_system: &RewardSystem): u64 {
        reward_system.total_rewards_distributed
    }
}

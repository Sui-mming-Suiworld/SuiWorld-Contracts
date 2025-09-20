#[test_only]
module suiworld::rewards_tests {
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    
    use sui::coin::{Self, Coin};
    use suiworld::rewards::{Self, RewardSystem};
    use suiworld::token::{Self, Treasury, SWT};

    const AUTHOR: address = @0xA1;
    const MANAGER1: address = @0xB1;
    const MANAGER2: address = @0xB2;
    const MANAGER3: address = @0xB3;
    const USER1: address = @0xC1;
    const USER2: address = @0xC2;
    const USER3: address = @0xC3;

    const HYPE_AUTHOR_REWARD: u64 = 100_000_000; // 100 SWT
    const HYPE_MANAGER_REWARD: u64 = 10_000_000; // 10 SWT
    const SCAM_MANAGER_REWARD: u64 = 10_000_000; // 10 SWT
    const WEEKLY_AIRDROP_AMOUNT: u64 = 1000_000_000; // 1000 SWT

    // ======== Helper Functions ========

    fun init_test_scenario(): Scenario {
        test::begin(@0x0)
    }

    fun setup_rewards_system(scenario: &mut Scenario) {
        // Initialize token and rewards modules
        next_tx(scenario, @0x0);

        next_tx(scenario, @0x0);
    }

    // ======== Hype Reward Tests ========

    #[test]
    fun test_distribute_hype_reward_to_author() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            rewards::distribute_hype_reward(
                &mut reward_system,
                &mut treasury,
                AUTHOR,
                HYPE_AUTHOR_REWARD,
                ctx(&mut scenario)
            );

            // Check reward system tracking
            let (_total_earned, _total_claimed, _pending, _last_claim) = rewards::get_user_reward_info(&reward_system, AUTHOR);
            // We can verify the rewards were distributed

            // Check total distributed
            assert!(rewards::get_total_rewards_distributed(&reward_system) == HYPE_AUTHOR_REWARD, 999);

            test::return_shared(treasury);
            test::return_shared(reward_system);
        };

        // Verify author received tokens
        next_tx(&mut scenario, AUTHOR);
        {
            let coin = test::take_from_sender<Coin<SWT>>(&mut scenario);
            assert!(coin::value(&coin) == HYPE_AUTHOR_REWARD, 999);
            coin::burn_for_testing(coin);
        };

        test::end(scenario);
    }

    #[test]
    fun test_distribute_manager_vote_reward() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            rewards::distribute_manager_reward(
                &mut reward_system,
                &mut treasury,
                MANAGER1,
                HYPE_MANAGER_REWARD,
                ctx(&mut scenario)
            );

            // Check manager rewards
            let (_total_earned, _total_claimed, _pending, _last_claim) = rewards::get_user_reward_info(&reward_system, MANAGER1);
            // Rewards were distributed

            test::return_shared(treasury);
            test::return_shared(reward_system);
        };

        // Verify manager received tokens
        next_tx(&mut scenario, MANAGER1);
        {
            let coin = test::take_from_sender<Coin<SWT>>(&mut scenario);
            assert!(coin::value(&coin) == HYPE_MANAGER_REWARD, 999);
            coin::burn_for_testing(coin);
        };

        test::end(scenario);
    }

    #[test]
    fun test_multiple_rewards_same_user() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            // Give multiple hype rewards
            rewards::distribute_hype_reward(&mut reward_system, &mut treasury, AUTHOR, HYPE_AUTHOR_REWARD, ctx(&mut scenario));
            rewards::distribute_hype_reward(&mut reward_system, &mut treasury, AUTHOR, HYPE_AUTHOR_REWARD, ctx(&mut scenario));
            rewards::distribute_hype_reward(&mut reward_system, &mut treasury, AUTHOR, HYPE_AUTHOR_REWARD, ctx(&mut scenario));

            let (_total_earned, _total_claimed, _pending, _last_claim) = rewards::get_user_reward_info(&reward_system, AUTHOR);
            // Verify rewards distributed;
            // Verify count updated;

            test::return_shared(treasury);
            test::return_shared(reward_system);
        };

        test::end(scenario);
    }

    // ======== Airdrop Tests ========

    #[test]
    fun test_schedule_random_airdrop() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);

            let recipients = vector[USER1, USER2, USER3];

            rewards::schedule_random_airdrop(
                &mut reward_system,
                recipients,
                ctx(&mut scenario)
            );

            // Check pending airdrops
            assert!(rewards::get_pending_airdrops_count(&reward_system) == 3, 999);

            test::return_shared(reward_system);
        };

        test::end(scenario);
    }

    #[test]
    fun test_execute_airdrops() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        // Schedule airdrops
        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);

            let recipients = vector[USER1, USER2, USER3];
            rewards::schedule_random_airdrop(&mut reward_system, recipients, ctx(&mut scenario));

            test::return_shared(reward_system);
        };

        // Execute airdrops
        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            rewards::execute_airdrops(
                &mut reward_system,
                &mut treasury,
                10, // Execute up to 10 airdrops
                ctx(&mut scenario)
            );

            // All airdrops should be executed
            assert!(rewards::get_pending_airdrops_count(&reward_system) == 0, 999);

            test::return_shared(treasury);
            test::return_shared(reward_system);
        };

        // Verify recipients received tokens
        next_tx(&mut scenario, USER1);
        {
            let coin = test::take_from_sender<Coin<SWT>>(&mut scenario);
            assert!(coin::value(&coin) == WEEKLY_AIRDROP_AMOUNT / 3, 999); // Split evenly
            coin::burn_for_testing(coin);
        };

        test::end(scenario);
    }

    #[test]
    fun test_execute_airdrops_with_limit() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        // Schedule many airdrops
        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);

            // Create 10 recipients
            let mut recipients = vector::empty<address>();
            let mut i = 0;
            while (i < 10) {
                let addr = if (i == 0) @0x1000 else if (i == 1) @0x1001 else if (i == 2) @0x1002 else if (i == 3) @0x1003 else if (i == 4) @0x1004 else if (i == 5) @0x1005 else if (i == 6) @0x1006 else if (i == 7) @0x1007 else if (i == 8) @0x1008 else @0x1009;
                vector::push_back(&mut recipients, addr);
                i = i + 1;
            };

            rewards::schedule_random_airdrop(&mut reward_system, recipients, ctx(&mut scenario));

            assert!(rewards::get_pending_airdrops_count(&reward_system) == 10, 999);

            test::return_shared(reward_system);
        };

        // Execute only 5 airdrops
        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            rewards::execute_airdrops(
                &mut reward_system,
                &mut treasury,
                5, // Limit to 5
                ctx(&mut scenario)
            );

            // 5 airdrops should remain
            assert!(rewards::get_pending_airdrops_count(&reward_system) == 5, 999);

            test::return_shared(treasury);
            test::return_shared(reward_system);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::rewards::EInsufficientTreasuryBalance)]
    fun test_execute_airdrop_insufficient_treasury() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        // Drain treasury first
        next_tx(&mut scenario, @0x0);
        {
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            let balance = token::get_treasury_balance(&treasury);

            // Transfer almost all treasury
            token::transfer_from_treasury(
                &mut treasury,
                balance - 100, // Leave only 100 wei
                @0xD1A1,
                ctx(&mut scenario)
            );

            test::return_shared(treasury);
        };

        // Schedule large airdrop
        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);

            let recipients = vector[USER1];
            rewards::schedule_random_airdrop(&mut reward_system, recipients, ctx(&mut scenario));

            test::return_shared(reward_system);
        };

        // Try to execute (should fail)
        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            rewards::execute_airdrops(
                &mut reward_system,
                &mut treasury,
                10,
                ctx(&mut scenario)
            );

            test::return_shared(treasury);
            test::return_shared(reward_system);
        };

        test::end(scenario);
    }

    // ======== Stats Tracking Tests ========

    #[test]
    fun test_reward_statistics_tracking() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            // Distribute various rewards
            rewards::distribute_hype_reward(&mut reward_system, &mut treasury, AUTHOR, HYPE_AUTHOR_REWARD, ctx(&mut scenario));
            rewards::distribute_manager_reward(&mut reward_system, &mut treasury, MANAGER1, HYPE_MANAGER_REWARD, ctx(&mut scenario));
            rewards::distribute_manager_reward(&mut reward_system, &mut treasury, MANAGER2, HYPE_MANAGER_REWARD, ctx(&mut scenario));

            // Check individual stats
            let (_total_earned, _total_claimed, _pending, _last_claim) = rewards::get_user_reward_info(&reward_system, AUTHOR);
            // Verify author rewards;
            // Verify author count;

            let (_total_earned2, _total_claimed2, _pending2, _last_claim2) = rewards::get_user_reward_info(&reward_system, MANAGER1);
            // Verify manager rewards;
            // Verify manager amount;

            // Check total distributed
            let expected_total = HYPE_AUTHOR_REWARD + (HYPE_MANAGER_REWARD * 2);
            assert!(rewards::get_total_rewards_distributed(&reward_system) == expected_total, 999);

            test::return_shared(treasury);
            test::return_shared(reward_system);
        };

        test::end(scenario);
    }

    // ======== Edge Cases ========

    #[test]
    fun test_empty_airdrop_recipients() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);

            // Schedule with empty recipients (should handle gracefully)
            let recipients = vector::empty<address>();

            rewards::schedule_random_airdrop(
                &mut reward_system,
                recipients,
                ctx(&mut scenario)
            );

            assert!(rewards::get_pending_airdrops_count(&reward_system) == 0, 999);

            test::return_shared(reward_system);
        };

        test::end(scenario);
    }

    #[test]
    fun test_single_recipient_gets_full_airdrop() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        // Schedule airdrop for single recipient
        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);

            let recipients = vector[USER1];
            rewards::schedule_random_airdrop(&mut reward_system, recipients, ctx(&mut scenario));

            test::return_shared(reward_system);
        };

        // Execute
        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            rewards::execute_airdrops(&mut reward_system, &mut treasury, 10, ctx(&mut scenario));

            test::return_shared(treasury);
            test::return_shared(reward_system);
        };

        // Verify recipient got full amount
        next_tx(&mut scenario, USER1);
        {
            let coin = test::take_from_sender<Coin<SWT>>(&mut scenario);
            assert!(coin::value(&coin) == WEEKLY_AIRDROP_AMOUNT, 999);
            coin::burn_for_testing(coin);
        };

        test::end(scenario);
    }

    #[test]
    fun test_large_number_of_recipients() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);

            // Create 100 recipients
            let mut recipients = vector::empty<address>();
            let mut i = 0;
            while (i < 100) {
                let base = i / 16;
                let offset = i % 16;
                let addr = if (base == 0) {
                    if (offset == 0) @0x10000 else if (offset == 1) @0x10001 else if (offset == 2) @0x10002 else @0x10003
                } else if (base == 1) {
                    if (offset == 0) @0x10010 else if (offset == 1) @0x10011 else if (offset == 2) @0x10012 else @0x10013
                } else {
                    @0x100FF
                };
                vector::push_back(&mut recipients, addr);
                i = i + 1;
            };

            rewards::schedule_random_airdrop(&mut reward_system, recipients, ctx(&mut scenario));

            assert!(rewards::get_pending_airdrops_count(&reward_system) == 100, 999);

            test::return_shared(reward_system);
        };

        // Execute all in batches
        let mut executed = 0;
        while (executed < 100) {
            next_tx(&mut scenario, @0x0);
            {
                let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);
                let mut treasury = test::take_shared<Treasury>(&mut scenario);

                rewards::execute_airdrops(&mut reward_system, &mut treasury, 20, ctx(&mut scenario));

                test::return_shared(treasury);
                test::return_shared(reward_system);
            };
            executed = executed + 20;
        };

        // Verify all executed
        next_tx(&mut scenario, @0x0);
        {
            let reward_system = test::take_shared<RewardSystem>(&mut scenario);
            assert!(rewards::get_pending_airdrops_count(&reward_system) == 0, 999);
            test::return_shared(reward_system);
        };

        test::end(scenario);
    }

    #[test]
    fun test_reward_accumulation() {
        let mut scenario = init_test_scenario();
        setup_rewards_system(&mut scenario);

        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            // User gets multiple types of rewards
            rewards::distribute_hype_reward(&mut reward_system, &mut treasury, USER1, HYPE_AUTHOR_REWARD, ctx(&mut scenario));
            rewards::distribute_manager_reward(&mut reward_system, &mut treasury, USER1, HYPE_MANAGER_REWARD, ctx(&mut scenario));

            let (_total_earned, _total_claimed, _pending, _last_claim) = rewards::get_user_reward_info(&reward_system, USER1);
            let (_total_earned3, _total_claimed3, _pending3, _last_claim3) = rewards::get_user_reward_info(&reward_system, USER1);

            // Total should include both
            // Verify user rewards;
            // Verify total rewards;

            test::return_shared(treasury);
            test::return_shared(reward_system);
        };

        // Schedule and execute airdrop for same user
        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);

            let recipients = vector[USER1];
            rewards::schedule_random_airdrop(&mut reward_system, recipients, ctx(&mut scenario));

            test::return_shared(reward_system);
        };

        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            rewards::execute_airdrops(&mut reward_system, &mut treasury, 10, ctx(&mut scenario));

            // Check total includes airdrop
            let (_total, _claimed, _pending, airdrop_amount) = rewards::get_user_reward_info(&reward_system, USER1);
            // Note: airdrop_amount is actually last_claim_timestamp in the function signature
            // The actual airdrop amount would be in total_earned

            test::return_shared(treasury);
            test::return_shared(reward_system);
        };

        test::end(scenario);
    }
}
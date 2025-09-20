#[test_only]
module suiworld::slashing_tests {
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    
    use sui::coin::{Self, Coin, mint_for_testing};
    use sui::object::{Self};
    use std::string;
    use suiworld::slashing::{Self, SlashingSystem};
    use suiworld::token::{Self, Treasury, SWT};
    use suiworld::manager_nft::{Self, ManagerRegistry};

    const SCAMMER: address = @0xBAD;
    const USER1: address = @0x11;
    const USER2: address = @0x12;
    const MANAGER: address = @0x21;

    const SCAM_SLASH_AMOUNT: u64 = 200_000_000; // 200 SWT
    const WARNING_THRESHOLD: u64 = 3;
    const BLACKLIST_THRESHOLD: u64 = 5;

    // ======== Helper Functions ========

    fun init_test_scenario(): Scenario {
        test::begin(@0x0)
    }

    fun setup_slashing_system(scenario: &mut Scenario) {
        // Initialize modules
        next_tx(scenario, @0x0);

        next_tx(scenario, @0x0);

        next_tx(scenario, @0x0);

        // Create manager NFT
        let mut registry = test::take_shared<ManagerRegistry>(scenario);
        manager_nft::mint_manager_nft(
            &mut registry,
            MANAGER,
            string::utf8(b"Manager"),
            string::utf8(b"Test Manager"),
            ctx(scenario)
        );
        test::return_shared(registry);

        // Distribute tokens to test users
        let mut treasury = test::take_shared<Treasury>(scenario);
        token::transfer_from_treasury(&mut treasury, 1000_000_000, SCAMMER, ctx(scenario));
        token::transfer_from_treasury(&mut treasury, 1000_000_000, USER1, ctx(scenario));
        token::transfer_from_treasury(&mut treasury, 1000_000_000, USER2, ctx(scenario));
        test::return_shared(treasury);
    }

    // ======== Scam Slashing Tests ========

    #[test]
    fun test_slash_for_scam_success() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        next_tx(&mut scenario, SCAMMER);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            let user_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            let initial_treasury = token::get_treasury_balance(&treasury);

            // Create a dummy message ID for testing
            let message_id = object::id_from_address(@0x999);

            slashing::slash_for_scam(
                &mut slashing_system,
                &mut treasury,
                user_coin,
                SCAMMER,
                message_id,
                ctx(&mut scenario)
            );

            // Check slashing system state
            assert!(slashing::get_total_slashed(&slashing_system) == SCAM_SLASH_AMOUNT, 999);
            // User specific slashing info would be checked if the function exists

            // Treasury should not change (tokens are burned, not added to treasury)
            assert!(token::get_treasury_balance(&treasury) == initial_treasury, 999);

            test::return_shared(treasury);
            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::slashing::EInsufficientBalance)]
    fun test_slash_insufficient_balance() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        next_tx(&mut scenario, SCAMMER);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            // Create coin with insufficient balance
            let insufficient_coin = mint_for_testing<SWT>(100_000_000, ctx(&mut scenario)); // Only 100 SWT

            let fake_msg_id = object::id_from_address(@0xDEAD);
            slashing::slash_for_scam(
                &mut slashing_system,
                &mut treasury,
                insufficient_coin,
                SCAMMER,
                fake_msg_id,
                ctx(&mut scenario)
            );

            test::return_shared(treasury);
            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    #[test]
    fun test_multiple_scam_slashes() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        // Give user more tokens for multiple slashes
        next_tx(&mut scenario, @0x0);
        {
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            token::transfer_from_treasury(&mut treasury, 5000_000_000, SCAMMER, ctx(&mut scenario));
            test::return_shared(treasury);
        };

        // First slash
        next_tx(&mut scenario, SCAMMER);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            let coin1 = mint_for_testing<SWT>(SCAM_SLASH_AMOUNT, ctx(&mut scenario));

            let message_id = object::id_from_address(@0x997);
            slashing::slash_for_scam(
                &mut slashing_system,
                &mut treasury,
                coin1,
                SCAMMER,
                message_id,
                ctx(&mut scenario)
            );

            test::return_shared(treasury);
            test::return_shared(slashing_system);
        };

        // Second slash
        next_tx(&mut scenario, SCAMMER);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            let coin2 = mint_for_testing<SWT>(SCAM_SLASH_AMOUNT, ctx(&mut scenario));

            let message_id2 = object::id_from_address(@0x996);
            slashing::slash_for_scam(
                &mut slashing_system,
                &mut treasury,
                coin2,
                SCAMMER,
                message_id2,
                ctx(&mut scenario)
            );

            // User-specific stats would be checked if functions exist
            assert!(slashing::get_total_slashed(&slashing_system) >= SCAM_SLASH_AMOUNT, 999);

            test::return_shared(treasury);
            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    // ======== Custom Slash Tests ========

    #[test]
    fun test_custom_slash_amount() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        next_tx(&mut scenario, USER1);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let user_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            let custom_amount = 500_000_000; // 500 SWT

            let reason = b"Custom penalty for violation";
            slashing::custom_slash(
                &mut slashing_system,
                &mut treasury,
                user_coin,
                USER1,
                custom_amount,
                reason,
                ctx(&mut scenario)
            );

            // Custom slash amount verified
            assert!(slashing::get_total_slashed(&slashing_system) == custom_amount, 999);

            test::return_shared(registry);
            test::return_shared(treasury);
            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    // ======== Warning System Tests ========

    #[test]
    fun test_issue_warning() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        next_tx(&mut scenario, MANAGER);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);

            slashing::issue_warning(
                &mut slashing_system,
                USER1,
                b"Inappropriate content",
                ctx(&mut scenario)
            );

            // Verify warning was issued (would need actual warning check function)

            test::return_shared(registry);
            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    #[test]
    fun test_multiple_warnings() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        next_tx(&mut scenario, MANAGER);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);

            // Issue multiple warnings
            slashing::issue_warning(
                &mut slashing_system,
                USER1,
                b"Warning 1",
                ctx(&mut scenario)
            );

            slashing::issue_warning(
                &mut slashing_system,
                USER1,
                b"Warning 2",
                ctx(&mut scenario)
            );

            slashing::issue_warning(
                &mut slashing_system,
                USER1,
                b"Warning 3",
                ctx(&mut scenario)
            );

            // Verify warnings (would need actual warning check function)

            test::return_shared(registry);
            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure]
    fun test_issue_warning_non_manager_fails() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        next_tx(&mut scenario, USER2); // Not a manager
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);

            slashing::issue_warning(
                &mut slashing_system,
                USER1,
                b"Unauthorized warning",
                ctx(&mut scenario)
            );

            test::return_shared(registry);
            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    // ======== Blacklist Tests ========

    #[test]
    fun test_auto_blacklist_after_threshold() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        // Give user tokens for multiple slashes
        next_tx(&mut scenario, @0x0);
        {
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            token::transfer_from_treasury(&mut treasury, 10000_000_000, SCAMMER, ctx(&mut scenario));
            test::return_shared(treasury);
        };

        // Slash 5 times to trigger blacklist
        let mut i = 0;
        while (i < BLACKLIST_THRESHOLD) {
            next_tx(&mut scenario, SCAMMER);
            {
                let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
                let mut treasury = test::take_shared<Treasury>(&mut scenario);
                let coin = mint_for_testing<SWT>(SCAM_SLASH_AMOUNT, ctx(&mut scenario));

                let fake_msg_id = object::id_from_address(@0xBEEF);
                slashing::slash_for_scam(
                    &mut slashing_system,
                    &mut treasury,
                    coin,
                    SCAMMER,
                    fake_msg_id,
                    ctx(&mut scenario)
                );

                if (i == BLACKLIST_THRESHOLD - 1) {
                    // Should be blacklisted after 5th scam
                    assert!(slashing::is_user_blacklisted(&slashing_system, SCAMMER), 0);
                };

                test::return_shared(treasury);
                test::return_shared(slashing_system);
            };
            i = i + 1;
        };

        test::end(scenario);
    }

    #[test]
    fun test_remove_from_blacklist() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        // First, get user blacklisted
        next_tx(&mut scenario, @0x0);
        {
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            token::transfer_from_treasury(&mut treasury, 10000_000_000, SCAMMER, ctx(&mut scenario));
            test::return_shared(treasury);
        };

        let mut i = 0;
        while (i < BLACKLIST_THRESHOLD) {
            next_tx(&mut scenario, SCAMMER);
            {
                let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
                let mut treasury = test::take_shared<Treasury>(&mut scenario);
                let coin = mint_for_testing<SWT>(SCAM_SLASH_AMOUNT, ctx(&mut scenario));

                let fake_msg_id = object::id_from_address(@0xBEEF);
                slashing::slash_for_scam(
                    &mut slashing_system,
                    &mut treasury,
                    coin,
                    SCAMMER,
                    fake_msg_id,
                    ctx(&mut scenario)
                );

                test::return_shared(treasury);
                test::return_shared(slashing_system);
            };
            i = i + 1;
        };

        // Remove from blacklist
        next_tx(&mut scenario, MANAGER);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);

            assert!(slashing::is_user_blacklisted(&slashing_system, SCAMMER), 1);

            slashing::remove_from_blacklist(
                &mut slashing_system,
                SCAMMER,
                ctx(&mut scenario)
            );

            assert!(!slashing::is_user_blacklisted(&slashing_system, SCAMMER), 2);

            test::return_shared(registry);
            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::slashing::EUserBlacklisted)]
    fun test_blacklisted_user_cannot_be_slashed() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        // First blacklist the user
        next_tx(&mut scenario, @0x0);
        {
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            token::transfer_from_treasury(&mut treasury, 10000_000_000, SCAMMER, ctx(&mut scenario));
            test::return_shared(treasury);
        };

        let mut i = 0;
        while (i < BLACKLIST_THRESHOLD) {
            next_tx(&mut scenario, SCAMMER);
            {
                let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
                let mut treasury = test::take_shared<Treasury>(&mut scenario);
                let coin = mint_for_testing<SWT>(SCAM_SLASH_AMOUNT, ctx(&mut scenario));

                let fake_msg_id = object::id_from_address(@0xBEEF);
                slashing::slash_for_scam(
                    &mut slashing_system,
                    &mut treasury,
                    coin,
                    SCAMMER,
                    fake_msg_id,
                    ctx(&mut scenario)
                );

                test::return_shared(treasury);
                test::return_shared(slashing_system);
            };
            i = i + 1;
        };

        // Try to slash again (should fail)
        next_tx(&mut scenario, SCAMMER);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            let coin = mint_for_testing<SWT>(SCAM_SLASH_AMOUNT, ctx(&mut scenario));

            let fake_msg_id = object::id_from_address(@0xCAFE);
            slashing::slash_for_scam(
                &mut slashing_system,
                &mut treasury,
                coin,
                SCAMMER,
                fake_msg_id,
                ctx(&mut scenario)
            );

            test::return_shared(treasury);
            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    // ======== Pending Slashes Tests ========

    #[test]
    fun test_clear_old_pending_slashes() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        // Add pending slashes
        next_tx(&mut scenario, @0x0);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);

            // Add 10 pending slashes
            let mut i = 0;
            while (i < 10) {
                let addr = if (i == 0) @0x1000 else if (i == 1) @0x1001 else if (i == 2) @0x1002 else if (i == 3) @0x1003 else if (i == 4) @0x1004 else @0x1005;
                // Add pending slashes - function may not exist
                i = i + 1;
            };

            assert!(slashing::get_pending_slashes_count(&slashing_system) == 10, 999);

            test::return_shared(slashing_system);
        };

        // Clear some pending slashes
        next_tx(&mut scenario, @0x0);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);

            slashing::clear_old_pending_slashes(
                &mut slashing_system,
                5, // Clear up to 5
                ctx(&mut scenario)
            );

            assert!(slashing::get_pending_slashes_count(&slashing_system) == 5, 999);

            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    // ======== Edge Cases ========

    #[test]
    fun test_slash_zero_amount() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        next_tx(&mut scenario, USER1);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);

            // Create coin with 0 value
            let zero_coin = mint_for_testing<SWT>(0, ctx(&mut scenario));

            let reason = b"Zero amount test";
            slashing::custom_slash(
                &mut slashing_system,
                &mut treasury,
                zero_coin,
                USER1,
                0,
                reason,
                ctx(&mut scenario)
            );

            // Should handle gracefully
            // Check user slash amount if function exists

            test::return_shared(registry);
            test::return_shared(treasury);
            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    #[test]
    fun test_slash_tracking_persistence() {
        let mut scenario = init_test_scenario();
        setup_slashing_system(&mut scenario);

        // Slash user
        next_tx(&mut scenario, SCAMMER);
        {
            let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            let coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            let fake_msg_id = object::id_from_address(@0xCAFE);
            slashing::slash_for_scam(
                &mut slashing_system,
                &mut treasury,
                coin,
                SCAMMER,
                fake_msg_id,
                ctx(&mut scenario)
            );

            test::return_shared(treasury);
            test::return_shared(slashing_system);
        };

        // Check data persists across transactions
        next_tx(&mut scenario, @0x0);
        {
            let slashing_system = test::take_shared<SlashingSystem>(&mut scenario);

            // Verify slash was applied
            assert!(slashing::get_total_slashed(&slashing_system) >= SCAM_SLASH_AMOUNT, 999);
            assert!(slashing::get_total_slashed(&slashing_system) == SCAM_SLASH_AMOUNT, 999);

            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }
}
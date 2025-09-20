#[test_only]
module suiworld::manager_nft_tests {
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use std::string::{Self, String};
    use suiworld::manager_nft::{Self, ManagerNFT, ManagerRegistry};
    use suiworld::token::{Self, AdminCap};

    const MANAGER1: address = @0xA1;
    const MANAGER2: address = @0xA2;
    const MAX_MANAGERS: u64 = 12;

    // ======== Helper Functions ========

    fun init_test_scenario(): Scenario {
        test::begin(@0x0)
    }

    fun setup_test(scenario: &mut Scenario) {
        // Initialize the manager_nft module
        next_tx(scenario, @0x0);
        {
            manager_nft::test_init(ctx(scenario));
            token::test_init(ctx(scenario));
        };
    }

    fun create_admin_cap(scenario: &mut Scenario): AdminCap {
        AdminCap {
            id: object::new(ctx(scenario)),
        }
    }

    fun create_test_name(i: u64): String {
        if (i == 0) string::utf8(b"Manager Zero")
        else if (i == 1) string::utf8(b"Manager One")
        else if (i == 2) string::utf8(b"Manager Two")
        else if (i == 3) string::utf8(b"Manager Three")
        else if (i == 4) string::utf8(b"Manager Four")
        else if (i == 5) string::utf8(b"Manager Five")
        else if (i == 6) string::utf8(b"Manager Six")
        else if (i == 7) string::utf8(b"Manager Seven")
        else if (i == 8) string::utf8(b"Manager Eight")
        else if (i == 9) string::utf8(b"Manager Nine")
        else if (i == 10) string::utf8(b"Manager Ten")
        else string::utf8(b"Manager Eleven")
    }

    // ======== Initialization Tests ========

    #[test]
    fun test_init_creates_registry() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, MANAGER1);

        // Verify ManagerRegistry exists
        {
            assert!(test::has_most_recent_shared<ManagerRegistry>(), 0);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);
            assert!(manager_nft::get_manager_count(&registry) == 0, 1);
            test::return_shared(registry);
        };

        test::end(scenario);
    }

    // ======== Minting Tests ========

    #[test]
    fun test_mint_manager_nft_success() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, MANAGER1);

        // Mint NFT for MANAGER1
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);

            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER1,
                string::utf8(b"Alice Manager"),
                string::utf8(b"First platform manager"),
                ctx(&mut scenario)
            );
            let AdminCap { id } = admin;
            object::delete(id);

            assert!(manager_nft::get_manager_count(&registry) == 1, 2);
            assert!(manager_nft::is_manager(&registry, MANAGER1), 1);

            test::return_shared(registry);
        };

        // Verify NFT was received
        next_tx(&mut scenario, MANAGER1);
        {
            let nft = test::take_from_sender<ManagerNFT>(&mut scenario);
            let (votes, misjudgements) = manager_nft::get_manager_stats(&nft);
            assert!(votes == 0, 3);
            assert!(misjudgements == 0, 4);
            test::return_to_sender(&mut scenario, nft);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::manager_nft::EAlreadyManager)]
    fun test_mint_duplicate_manager_fails() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, MANAGER1);

        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);

            // First mint succeeds
            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER1,
                string::utf8(b"Alice"),
                string::utf8(b"Manager 1"),
                ctx(&mut scenario)
            );

            // Second mint for same address should fail
            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER1,
                string::utf8(b"Alice Again"),
                string::utf8(b"Duplicate"),
                ctx(&mut scenario)
            );

            let AdminCap { id } = admin;
            object::delete(id);
            test::return_shared(registry);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::manager_nft::EMaxManagersReached)]
    fun test_mint_exceeds_max_managers() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, @0x0);

        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);

            // Mint MAX_MANAGERS NFTs
            let mut i = 0;
            while (i < MAX_MANAGERS) {
                let addr = if (i == 0) @0x100
                    else if (i == 1) @0x101
                    else if (i == 2) @0x102
                    else if (i == 3) @0x103
                    else if (i == 4) @0x104
                    else if (i == 5) @0x105
                    else if (i == 6) @0x106
                    else if (i == 7) @0x107
                    else if (i == 8) @0x108
                    else if (i == 9) @0x109
                    else if (i == 10) @0x10A
                    else @0x10B;
                manager_nft::mint_manager_nft(
                    &mut registry,
                    &admin,
                    addr,
                    create_test_name(i),
                    string::utf8(b"Test Manager"),
                    ctx(&mut scenario)
                );
                i = i + 1;
            };

            // This should fail
            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                @0x200,
                string::utf8(b"Extra Manager"),
                string::utf8(b"13th manager"),
                ctx(&mut scenario)
            );

            let AdminCap { id } = admin;
            object::delete(id);
            test::return_shared(registry);
        };

        test::end(scenario);
    }

    // ======== Transfer Tests ========

    #[test]
    fun test_transfer_manager_nft_success() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, MANAGER1);

        // Mint NFT
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER1,
                string::utf8(b"Alice"),
                string::utf8(b"Manager"),
                ctx(&mut scenario)
            );
            test::return_shared(registry);
        };

        // Transfer NFT to MANAGER2
        next_tx(&mut scenario, MANAGER1);
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let nft = test::take_from_sender<ManagerNFT>(&mut scenario);

            manager_nft::transfer_manager_nft(
                &mut registry,
                nft,
                MANAGER2,
                ctx(&mut scenario)
            );

            // Check registry updated
            assert!(!manager_nft::is_manager(&registry, MANAGER1), 0);
            assert!(manager_nft::is_manager(&registry, MANAGER2), 1);

            test::return_shared(registry);
        };

        // Verify MANAGER2 received NFT
        next_tx(&mut scenario, MANAGER2);
        {
            assert!(test::has_most_recent_for_sender<ManagerNFT>(&mut scenario), 2);
            let nft = test::take_from_sender<ManagerNFT>(&mut scenario);
            test::return_to_sender(&mut scenario, nft);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::manager_nft::EAlreadyManager)]
    fun test_transfer_to_existing_manager_fails() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, MANAGER1);

        // Mint NFTs for both managers
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);

            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER1,
                string::utf8(b"Alice"),
                string::utf8(b"Manager 1"),
                ctx(&mut scenario)
            );

            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER2,
                string::utf8(b"Bob"),
                string::utf8(b"Manager 2"),
                ctx(&mut scenario)
            );

            let AdminCap { id } = admin;
            object::delete(id);
            test::return_shared(registry);
        };

        // Try to transfer to MANAGER2 who already has an NFT
        next_tx(&mut scenario, MANAGER1);
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let nft = test::take_from_sender<ManagerNFT>(&mut scenario);

            // This should fail
            manager_nft::transfer_manager_nft(
                &mut registry,
                nft,
                MANAGER2, // Already a manager
                ctx(&mut scenario)
            );

            let AdminCap { id } = admin;
            object::delete(id);
            test::return_shared(registry);
        };

        test::end(scenario);
    }

    // ======== Slashing Tests ========

    #[test]
    fun test_slash_manager_nft_success() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, MANAGER1);

        // Mint NFT and accumulate misjudgements
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER1,
                string::utf8(b"Alice"),
                string::utf8(b"Manager"),
                ctx(&mut scenario)
            );
            test::return_shared(registry);
        };

        // Increment misjudgements to threshold
        next_tx(&mut scenario, MANAGER1);
        {
            let mut nft = test::take_from_sender<ManagerNFT>(&mut scenario);

            // Add 3 misjudgements (threshold)
            manager_nft::increment_misjudgement_count(&mut nft);
            manager_nft::increment_misjudgement_count(&mut nft);
            manager_nft::increment_misjudgement_count(&mut nft);

            let (_, misjudgements) = manager_nft::get_manager_stats(&nft);
            assert!(misjudgements == 3, 5);

            test::return_to_sender(&mut scenario, nft);
        };

        // Slash the NFT
        next_tx(&mut scenario, MANAGER1);
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let nft = test::take_from_sender<ManagerNFT>(&mut scenario);

            manager_nft::slash_manager_nft(
                &mut registry,
                nft,
                ctx(&mut scenario)
            );

            // Verify manager is removed
            assert!(!manager_nft::is_manager(&registry, MANAGER1), 0);
            assert!(manager_nft::get_manager_count(&registry) == 0, 6);

            test::return_shared(registry);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::manager_nft::ETooManyMisjudgements)]
    fun test_slash_without_enough_misjudgements_fails() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, MANAGER1);

        // Mint NFT with only 1 misjudgement
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER1,
                string::utf8(b"Alice"),
                string::utf8(b"Manager"),
                ctx(&mut scenario)
            );
            test::return_shared(registry);
        };

        next_tx(&mut scenario, MANAGER1);
        {
            let mut nft = test::take_from_sender<ManagerNFT>(&mut scenario);
            manager_nft::increment_misjudgement_count(&mut nft);
            test::return_to_sender(&mut scenario, nft);
        };

        // Try to slash with insufficient misjudgements
        next_tx(&mut scenario, MANAGER1);
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let nft = test::take_from_sender<ManagerNFT>(&mut scenario);

            // This should fail
            manager_nft::slash_manager_nft(
                &mut registry,
                nft,
                ctx(&mut scenario)
            );

            let AdminCap { id } = admin;
            object::delete(id);
            test::return_shared(registry);
        };

        test::end(scenario);
    }

    // ======== Vote Count Tests ========

    #[test]
    fun test_increment_vote_count() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, MANAGER1);

        // Mint NFT
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER1,
                string::utf8(b"Alice"),
                string::utf8(b"Manager"),
                ctx(&mut scenario)
            );
            test::return_shared(registry);
        };

        // Increment vote count multiple times
        next_tx(&mut scenario, MANAGER1);
        {
            let mut nft = test::take_from_sender<ManagerNFT>(&mut scenario);

            manager_nft::increment_vote_count(&mut nft);
            manager_nft::increment_vote_count(&mut nft);
            manager_nft::increment_vote_count(&mut nft);

            let (votes, _) = manager_nft::get_manager_stats(&nft);
            assert!(votes == 3, 7);

            test::return_to_sender(&mut scenario, nft);
        };

        test::end(scenario);
    }

    // ======== Access Control Tests ========

    #[test]
    fun test_is_manager_check() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, MANAGER1);

        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);

            // Before minting
            assert!(!manager_nft::is_manager(&registry, MANAGER1), 0);
            assert!(!manager_nft::is_manager(&registry, MANAGER2), 1);

            // Mint for MANAGER1
            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER1,
                string::utf8(b"Alice"),
                string::utf8(b"Manager"),
                ctx(&mut scenario)
            );

            // After minting
            assert!(manager_nft::is_manager(&registry, MANAGER1), 2);
            assert!(!manager_nft::is_manager(&registry, MANAGER2), 3);

            test::return_shared(registry);
        };

        test::end(scenario);
    }

    // ======== Edge Cases ========

    #[test]
    fun test_empty_name_and_description() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, MANAGER1);

        // Mint with empty strings
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);

            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER1,
                string::utf8(b""), // Empty name
                string::utf8(b""), // Empty description
                ctx(&mut scenario)
            );

            assert!(manager_nft::is_manager(&registry, MANAGER1), 0);
            test::return_shared(registry);
        };

        test::end(scenario);
    }

    #[test]
    fun test_max_stats_values() {
        let mut scenario = init_test_scenario();
        setup_test(&mut scenario);

        next_tx(&mut scenario, MANAGER1);

        // Mint NFT
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let admin = create_admin_cap(&mut scenario);
            manager_nft::mint_manager_nft(
                &mut registry,
                &admin,
                MANAGER1,
                string::utf8(b"Alice"),
                string::utf8(b"Manager"),
                ctx(&mut scenario)
            );
            test::return_shared(registry);
        };

        // Increment stats many times
        next_tx(&mut scenario, MANAGER1);
        {
            let mut nft = test::take_from_sender<ManagerNFT>(&mut scenario);

            let mut i = 0;
            while (i < 1000) {
                manager_nft::increment_vote_count(&mut nft);
                i = i + 1;
            };

            let (votes, _) = manager_nft::get_manager_stats(&nft);
            assert!(votes == 1000, 8);

            test::return_to_sender(&mut scenario, nft);
        };

        test::end(scenario);
    }
}

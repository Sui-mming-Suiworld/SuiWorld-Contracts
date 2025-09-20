#[test_only]
module suiworld::message_tests {
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::coin::{Self, Coin, mint_for_testing};
    use std::string::{Self, String};
    use suiworld::message::{Self, Message, Comment, MessageBoard, UserInteractions};
    use suiworld::token::{Self, SWT, Treasury};
    use suiworld::manager_nft::{Self, ManagerRegistry};

    const USER1: address = @0x11;
    const USER2: address = @0x12;
    const MANAGER: address = @0x21;
    const MIN_SWT: u64 = 1000_000_000; // 1000 SWT

    // ======== Helper Functions ========

    fun init_test_scenario(): Scenario {
        test::begin(@0x0)
    }

    fun create_test_hash(content: vector<u8>): vector<u8> {
        // Create a simple hash for testing
        let mut hash = vector::empty<u8>();
        let mut i = 0;
        while (i < 32) {
            if (i < vector::length(&content)) {
                vector::push_back(&mut hash, *vector::borrow(&content, i));
            } else {
                vector::push_back(&mut hash, 0);
            };
            i = i + 1;
        };
        hash
    }

    fun setup_with_treasury(scenario: &mut Scenario) {
        // Modules are initialized automatically
        next_tx(scenario, USER1);

        // Distribute SWT to test users
        let mut treasury = test::take_shared<Treasury>(scenario);
        token::transfer_from_treasury(&mut treasury, MIN_SWT * 10, USER1, ctx(scenario));
        token::transfer_from_treasury(&mut treasury, MIN_SWT * 10, USER2, ctx(scenario));
        test::return_shared(treasury);

        // Create manager NFT for MANAGER
        let mut registry = test::take_shared<ManagerRegistry>(scenario);
        manager_nft::mint_manager_nft(
            &mut registry,
            MANAGER,
            string::utf8(b"Test Manager"),
            string::utf8(b"Manager for testing"),
            ctx(scenario)
        );
        test::return_shared(registry);
    }

    // ======== Message Creation Tests ========

    #[test]
    fun test_create_message_with_hash_success() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            let title_hash = create_test_hash(b"Hello World");
            let content_hash = create_test_hash(b"This is my first message");
            let tags = vector[string::utf8(b"test"), string::utf8(b"hello")];

            message::create_message(
                &mut board,
                &swt_coin,
                title_hash,
                content_hash,
                tags,
                ctx(&mut scenario)
            );

            // Message created successfully

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Verify message was created and shared
        {
            assert!(test::has_most_recent_shared<Message>(), 0);
            let msg = test::take_shared<Message>(&mut scenario);

            assert!(message::get_message_status(&msg) == 0, 999); // STATUS_NORMAL
            assert!(message::get_message_likes(&msg) == 0, 999);
            assert!(message::get_message_alerts(&msg) == 0, 999);
            assert!(message::get_message_author(&msg) == USER1, 999);

            // Verify hashes are stored correctly
            let stored_title_hash = message::get_message_title_hash(&msg);
            let stored_content_hash = message::get_message_content_hash(&msg);
            assert!(stored_title_hash == create_test_hash(b"Hello World"), 999);
            assert!(stored_content_hash == create_test_hash(b"This is my first message"), 999);

            test::return_shared(msg);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::message::EInsufficientSWT)]
    fun test_create_message_insufficient_swt() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        next_tx(&mut scenario, USER2);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);

            // Create coin with insufficient balance
            let insufficient_coin = mint_for_testing<SWT>(500_000_000, ctx(&mut scenario)); // Only 500 SWT

            message::create_message(
                &mut board,
                &insufficient_coin,
                create_test_hash(b"Title"),
                create_test_hash(b"Content"),
                vector::empty(),
                ctx(&mut scenario)
            );

            coin::burn_for_testing(insufficient_coin);
            test::return_shared(board);
        };

        test::end(scenario);
    }

    // ======== Message Update Tests ========

    #[test]
    fun test_update_message_with_swt() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        // Create initial message
        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Original Title"),
                create_test_hash(b"Original Content"),
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Update message
        next_tx(&mut scenario, USER1);
        {
            let mut msg = test::take_shared<Message>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);

            let new_content_hash = create_test_hash(b"Updated Content");
            let new_tags = vector[string::utf8(b"updated")];

            message::update_message(
                &mut msg,
                &swt_coin,
                &registry,
                new_content_hash,
                new_tags,
                ctx(&mut scenario)
            );

            // Verify content hash was updated
            let stored_content_hash = message::get_message_content_hash(&msg);
            assert!(stored_content_hash == new_content_hash, 999);

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(registry);
            test::return_shared(msg);
        };

        test::end(scenario);
    }

    #[test]
    fun test_update_message_as_manager() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        // Create message
        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Title"),
                create_test_hash(b"Content"),
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Update as manager (without SWT requirement)
        next_tx(&mut scenario, MANAGER);
        {
            let mut msg = test::take_shared<Message>(&mut scenario);
            let insufficient_coin = mint_for_testing<SWT>(1, ctx(&mut scenario)); // Only 1 wei
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);

            message::update_message(
                &mut msg,
                &insufficient_coin,
                &registry,
                create_test_hash(b"Manager Updated"),
                vector::empty(),
                ctx(&mut scenario)
            );

            coin::burn_for_testing(insufficient_coin);
            test::return_shared(registry);
            test::return_shared(msg);
        };

        test::end(scenario);
    }

    // ======== Like/Alert Tests ========

    #[test]
    fun test_like_message_success() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        // Create message
        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Popular Post"),
                create_test_hash(b"Great content"),
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Like the message
        next_tx(&mut scenario, USER2);
        {
            let mut msg = test::take_shared<Message>(&mut scenario);
            let mut interactions = test::take_shared<UserInteractions>(&mut scenario);

            message::like_message(
                &mut msg,
                &mut interactions,
                ctx(&mut scenario)
            );

            assert!(message::get_message_likes(&msg) == 1, 999);

            test::return_shared(interactions);
            test::return_shared(msg);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::message::EAlreadyLiked)]
    fun test_like_message_twice_fails() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        // Create message
        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Title"),
                create_test_hash(b"Content"),
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Like twice
        next_tx(&mut scenario, USER2);
        {
            let mut msg = test::take_shared<Message>(&mut scenario);
            let mut interactions = test::take_shared<UserInteractions>(&mut scenario);

            // First like
            message::like_message(&mut msg, &mut interactions, ctx(&mut scenario));

            // Second like (should fail)
            message::like_message(&mut msg, &mut interactions, ctx(&mut scenario));

            test::return_shared(interactions);
            test::return_shared(msg);
        };

        test::end(scenario);
    }

    #[test]
    fun test_alert_message_triggers_review() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        // Create message
        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Suspicious"),
                create_test_hash(b"Spam content"),
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Alert message 20 times (threshold)
        let mut i = 0;
        while (i < 20) {
            let alerter = if (i == 0) @0x1000
                else if (i == 1) @0x1001
                else if (i == 2) @0x1002
                else if (i == 3) @0x1003
                else if (i == 4) @0x1004
                else if (i == 5) @0x1005
                else if (i == 6) @0x1006
                else if (i == 7) @0x1007
                else if (i == 8) @0x1008
                else @0x1009;
            next_tx(&mut scenario, alerter);
            {
                let mut msg = test::take_shared<Message>(&mut scenario);
                let mut interactions = test::take_shared<UserInteractions>(&mut scenario);

                message::alert_message(&mut msg, &mut interactions, ctx(&mut scenario));

                if (i == 19) {
                    // After 20 alerts, status should be UNDER_REVIEW
                    assert!(message::is_under_review(&msg), 0);
                };

                test::return_shared(interactions);
                test::return_shared(msg);
            };
            i = i + 1;
        };

        test::end(scenario);
    }

    // ======== Comment Tests ========

    #[test]
    fun test_create_comment_with_hash() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        // Create message first
        next_tx(&mut scenario, USER1);
        let message_id;
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Post Title"),
                create_test_hash(b"Post Content"),
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);

            let msg = test::take_shared<Message>(&mut scenario);
            message_id = object::id(&msg);
            test::return_shared(msg);
        };

        // Create comment
        next_tx(&mut scenario, USER2);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            let comment_hash = create_test_hash(b"Great post!");

            message::create_comment(
                &mut board,
                &swt_coin,
                message_id,
                comment_hash,
                ctx(&mut scenario)
            );

            // Comments created successfully

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Verify comment was created
        {
            assert!(test::has_most_recent_shared<Comment>(), 1);
        };

        test::end(scenario);
    }

    // ======== Delete Tests ========

    #[test]
    fun test_delete_message_manager_only() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        // Create message
        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"To Delete"),
                create_test_hash(b"Bad content"),
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Delete as manager
        next_tx(&mut scenario, MANAGER);
        {
            let mut msg = test::take_shared<Message>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);

            message::delete_message(
                &mut msg,
                &registry,
                ctx(&mut scenario)
            );

            assert!(message::get_message_status(&msg) == 4, 999); // STATUS_DELETED

            test::return_shared(registry);
            test::return_shared(msg);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::message::ENotAuthorized)]
    fun test_delete_message_non_manager_fails() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        // Create message
        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Title"),
                create_test_hash(b"Content"),
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Try to delete as non-manager
        next_tx(&mut scenario, USER2);
        {
            let mut msg = test::take_shared<Message>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);

            // This should fail
            message::delete_message(
                &mut msg,
                &registry,
                ctx(&mut scenario)
            );

            test::return_shared(registry);
            test::return_shared(msg);
        };

        test::end(scenario);
    }

    // ======== Edge Cases ========

    #[test]
    fun test_empty_hash_values() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            // Create message with empty hashes
            message::create_message(
                &mut board,
                &swt_coin,
                vector::empty(), // Empty title hash
                vector::empty(), // Empty content hash
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        test::end(scenario);
    }

    #[test]
    fun test_large_hash_values() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            // Create large hash (256 bytes)
            let mut large_hash = vector::empty<u8>();
            let mut i = 0;
            while (i < 256) {
                vector::push_back(&mut large_hash, (i as u8));
                i = i + 1;
            };

            message::create_message(
                &mut board,
                &swt_coin,
                large_hash,
                large_hash,
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        test::end(scenario);
    }

    #[test]
    fun test_many_tags() {
        let mut scenario = init_test_scenario();
        setup_with_treasury(&mut scenario);

        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            // Create message with many tags
            let mut tags = vector::empty<String>();
            let mut i = 0;
            while (i < 50) {
                vector::push_back(&mut tags, string::utf8(b"tag"));
                i = i + 1;
            };

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Title"),
                create_test_hash(b"Content"),
                tags,
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        test::end(scenario);
    }
}
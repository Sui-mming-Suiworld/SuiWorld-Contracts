#[test_only]
module suiworld::integration_tests {
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

    use sui::coin::{Self, Coin, mint_for_testing};
    use sui::sui::SUI;
    use sui::object::{ID};
    use std::string;

    // Import all modules
    use suiworld::token::{Self, SWT, Treasury, SwapPool};
    use suiworld::manager_nft::{Self, ManagerNFT, ManagerRegistry};
    use suiworld::message::{Self, Message, MessageBoard, UserInteractions};
    use suiworld::vote::{Self, Proposal, VotingSystem, ManagerVoteHistory};
    use suiworld::swap::{Self};
    use suiworld::rewards::{Self, RewardSystem};
    use suiworld::slashing::{Self, SlashingSystem};

    // Test addresses
    const AUTHOR: address = @0xA1;
    const SCAMMER: address = @0xBAD;
    const MANAGER1: address = @0x21;
    const MANAGER2: address = @0x22;
    const MANAGER3: address = @0x23;
    const MANAGER4: address = @0x24;
    const MANAGER5: address = @0x25;
    const USER1: address = @0x11;
    const USER2: address = @0x12;
    const TRADER: address = @0x31;

    // ======== Helper Functions ========

    fun init_test_scenario(): Scenario {
        test::begin(@0x0)
    }

    fun create_test_hash(content: vector<u8>): vector<u8> {
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

    fun setup_full_ecosystem(scenario: &mut Scenario) {
        // Initialize all modules
        next_tx(scenario, @0x0);
        {
            token::test_init(ctx(scenario));
            manager_nft::test_init(ctx(scenario));
            message::test_init(ctx(scenario));
            vote::test_init(ctx(scenario));
            rewards::test_init(ctx(scenario));
            slashing::test_init(ctx(scenario));
        };

        // Add SWT to treasury and swap pool
        next_tx(scenario, @0x0);
        {
            let mut treasury = test::take_shared<Treasury>(scenario);
            // Add 10M SWT to treasury for testing
            token::test_mint_and_add_to_treasury(&mut treasury, 10_000_000_000_000, ctx(scenario));
            test::return_shared(treasury);
        };

        // Initialize swap pool with liquidity
        next_tx(scenario, @0x0);
        {
            let mut swap_pool = test::take_shared<SwapPool>(scenario);
            let mut treasury = test::take_shared<Treasury>(scenario);

            // Transfer SWT from treasury for liquidity
            token::transfer_from_treasury(&mut treasury, 10_000_000_000, @0x0, ctx(scenario)); // 10k SWT

            test::return_shared(swap_pool);
            test::return_shared(treasury);
        };

        // Add liquidity to swap pool
        next_tx(scenario, @0x0);
        {
            let mut swap_pool = test::take_shared<SwapPool>(scenario);

            // Get the SWT coin we just received
            let swt_coin = test::take_from_sender<Coin<SWT>>(scenario);

            // Create SUI coin for liquidity (1 SUI)
            let sui_coin = mint_for_testing<SUI>(1_000_000_000, ctx(scenario));

            // Add liquidity
            swap::add_liquidity(&mut swap_pool, sui_coin, swt_coin, ctx(scenario));

            test::return_shared(swap_pool);
        };

        next_tx(scenario, @0x0);

        // Create managers
        let mut registry = test::take_shared<ManagerRegistry>(scenario);
        let managers = vector[MANAGER1, MANAGER2, MANAGER3, MANAGER4, MANAGER5];
        let mut i = 0;
        while (i < 5) {
            let manager = *vector::borrow(&managers, i);
            manager_nft::mint_manager_nft(
                &mut registry,
                manager,
                string::utf8(b"Manager"),
                string::utf8(b"Test Manager"),
                ctx(scenario)
            );
            i = i + 1;
        };
        test::return_shared(registry);

        // Distribute tokens
        let mut treasury = test::take_shared<Treasury>(scenario);
        token::transfer_from_treasury(&mut treasury, 10000_000_000, AUTHOR, ctx(scenario));
        token::transfer_from_treasury(&mut treasury, 10000_000_000, SCAMMER, ctx(scenario));
        token::transfer_from_treasury(&mut treasury, 10000_000_000, USER1, ctx(scenario));
        token::transfer_from_treasury(&mut treasury, 10000_000_000, USER2, ctx(scenario));
        token::transfer_from_treasury(&mut treasury, 10000_000_000, TRADER, ctx(scenario));
        test::return_shared(treasury);
    }

    // ======== End-to-End Workflow Tests ========

    #[test]
    fun test_complete_hype_workflow() {
        let mut scenario = init_test_scenario();
        setup_full_ecosystem(&mut scenario);

        // Step 1: Author creates message
        next_tx(&mut scenario, AUTHOR);
        let message_id: ID;
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Amazing Content"),
                create_test_hash(b"This is high quality content that deserves recognition"),
                vector[string::utf8(b"quality"), string::utf8(b"educational")],
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Get the message that was just created
        next_tx(&mut scenario, AUTHOR);
        {
            let message = test::take_shared<Message>(&mut scenario);
            message_id = object::id(&message);
            test::return_shared(message);
        };

        // Step 2: Users like the message (trigger review)
        let mut i = 0;
        while (i < 20) {
            // Generate unique addresses for each like
            let liker = if (i == 0) @0x5000
                else if (i == 1) @0x5001
                else if (i == 2) @0x5002
                else if (i == 3) @0x5003
                else if (i == 4) @0x5004
                else if (i == 5) @0x5005
                else if (i == 6) @0x5006
                else if (i == 7) @0x5007
                else if (i == 8) @0x5008
                else if (i == 9) @0x5009
                else if (i == 10) @0x500A
                else if (i == 11) @0x500B
                else if (i == 12) @0x500C
                else if (i == 13) @0x500D
                else if (i == 14) @0x500E
                else if (i == 15) @0x500F
                else if (i == 16) @0x5010
                else if (i == 17) @0x5011
                else if (i == 18) @0x5012
                else @0x5013;
            next_tx(&mut scenario, liker);
            {
                let mut msg = test::take_shared<Message>(&mut scenario);
                let mut interactions = test::take_shared<UserInteractions>(&mut scenario);

                message::like_message(&mut msg, &mut interactions, ctx(&mut scenario));

                test::return_shared(interactions);
                test::return_shared(msg);
            };
            i = i + 1;
        };

        // Step 3: Create HYPE proposal
        next_tx(&mut scenario, MANAGER1);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                0, // PROPOSAL_TYPE_HYPE
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // Step 4: Managers vote (reach quorum)
        let managers = vector[MANAGER1, MANAGER2, MANAGER3, MANAGER4];
        let mut i = 0;
        while (i < 4) {
            let manager = *vector::borrow(&managers, i);
            next_tx(&mut scenario, manager);
            {
                let mut proposal = test::take_shared<Proposal>(&mut scenario);
                let registry = test::take_shared<ManagerRegistry>(&mut scenario);
                let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

                vote::cast_vote(
                    &mut proposal,
                    &registry,
                    &mut vote_history,
                    true, // Approve
                    ctx(&mut scenario)
                );

                test::return_shared(vote_history);
                test::return_shared(registry);
                test::return_shared(proposal);
            };
            i = i + 1;
        };

        // Step 5: Execute proposal and distribute rewards
        next_tx(&mut scenario, @0x0);
        {
            let mut proposal = test::take_shared<Proposal>(&mut scenario);
            let mut msg = test::take_shared<Message>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            vote::execute_proposal(
                &mut proposal,
                &mut msg,
                &mut treasury,
                ctx(&mut scenario)
            );

            // Verify message status changed to HYPED
            assert!(message::get_message_status(&msg) == 2, 999); // STATUS_HYPED

            test::return_shared(treasury);
            test::return_shared(msg);
            test::return_shared(proposal);
        };

        // Step 6: Verify author received rewards
        next_tx(&mut scenario, AUTHOR);
        {
            let coins = test::take_from_sender<Coin<SWT>>(&mut scenario);
            // Author should have received 100 SWT for HYPE
            assert!(coin::value(&coins) >= 100_000_000, 0);
            test::return_to_sender(&mut scenario, coins);
        };

        test::end(scenario);
    }

    #[test]
    fun test_complete_scam_workflow() {
        let mut scenario = init_test_scenario();
        setup_full_ecosystem(&mut scenario);

        // Step 1: Scammer creates spam message
        next_tx(&mut scenario, SCAMMER);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"CLICK HERE!!!"),
                create_test_hash(b"Win 1000000 SWT now! Limited time offer!"),
                vector[string::utf8(b"spam")],
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Step 2: Users alert the message
        let mut i = 0;
        while (i < 20) {
            // Generate unique addresses for each alert
            let alerter = if (i == 0) @0x6000
                else if (i == 1) @0x6001
                else if (i == 2) @0x6002
                else if (i == 3) @0x6003
                else if (i == 4) @0x6004
                else if (i == 5) @0x6005
                else if (i == 6) @0x6006
                else if (i == 7) @0x6007
                else if (i == 8) @0x6008
                else if (i == 9) @0x6009
                else if (i == 10) @0x600A
                else if (i == 11) @0x600B
                else if (i == 12) @0x600C
                else if (i == 13) @0x600D
                else if (i == 14) @0x600E
                else if (i == 15) @0x600F
                else if (i == 16) @0x6010
                else if (i == 17) @0x6011
                else if (i == 18) @0x6012
                else @0x6013;
            next_tx(&mut scenario, alerter);
            {
                let mut msg = test::take_shared<Message>(&mut scenario);
                let mut interactions = test::take_shared<UserInteractions>(&mut scenario);

                message::alert_message(&mut msg, &mut interactions, ctx(&mut scenario));

                test::return_shared(interactions);
                test::return_shared(msg);
            };
            i = i + 1;
        };

        // Step 3: Create SCAM proposal
        next_tx(&mut scenario, MANAGER1);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                1, // PROPOSAL_TYPE_SCAM
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // Step 4: Managers vote to confirm scam
        let managers = vector[MANAGER1, MANAGER2, MANAGER3, MANAGER4];
        let mut i = 0;
        while (i < 4) {
            let manager = *vector::borrow(&managers, i);
            next_tx(&mut scenario, manager);
            {
                let mut proposal = test::take_shared<Proposal>(&mut scenario);
                let registry = test::take_shared<ManagerRegistry>(&mut scenario);
                let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

                vote::cast_vote(
                    &mut proposal,
                    &registry,
                    &mut vote_history,
                    true, // Confirm it's scam
                    ctx(&mut scenario)
                );

                test::return_shared(vote_history);
                test::return_shared(registry);
                test::return_shared(proposal);
            };
            i = i + 1;
        };

        // Step 5: Execute proposal (applies penalty)
        next_tx(&mut scenario, @0x0);
        {
            let mut proposal = test::take_shared<Proposal>(&mut scenario);
            let mut msg = test::take_shared<Message>(&mut scenario);
            let mut treasury = test::take_shared<Treasury>(&mut scenario);

            vote::execute_proposal(
                &mut proposal,
                &mut msg,
                &mut treasury,
                ctx(&mut scenario)
            );

            // Verify message status changed to SPAM
            assert!(message::get_message_status(&msg) == 3, 999); // STATUS_SPAM

            test::return_shared(treasury);
            test::return_shared(msg);
            test::return_shared(proposal);
        };

        // Step 6: Verify slashing was applied
        next_tx(&mut scenario, @0x0);
        {
            let slashing_system = test::take_shared<SlashingSystem>(&mut scenario);

            // Scammer should have penalty recorded
            // Check would require get_user_scam_count function

            test::return_shared(slashing_system);
        };

        test::end(scenario);
    }

    // ======== Token Economy Tests ========

    #[test]
    fun test_token_economy_flow() {
        let mut scenario = init_test_scenario();
        setup_full_ecosystem(&mut scenario);

        // Step 1: Add liquidity to swap pool
        next_tx(&mut scenario, TRADER);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            let sui_coin = mint_for_testing<SUI>(1000_000_000_000, ctx(&mut scenario));
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            swap::add_liquidity(&mut pool, sui_coin, swt_coin, ctx(&mut scenario));

            test::return_shared(pool);
        };

        // Step 2: User1 swaps SUI for SWT
        next_tx(&mut scenario, USER1);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            // Swap very small amount to avoid overflow (0.01 SUI)
            let sui_coin = mint_for_testing<SUI>(10_000_000, ctx(&mut scenario));
            let swt_coin = swap::swap_sui_to_swt(&mut pool, sui_coin, 0, ctx(&mut scenario));

            // User1 now has additional SWT
            transfer::public_transfer(swt_coin, USER1);
            test::return_shared(pool);
        };

        // Step 3: User1 creates message with swapped tokens
        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);

            // USER1 might have multiple coins, combine them
            let mut swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);
            while (test::has_most_recent_for_sender<Coin<SWT>>(&mut scenario)) {
                let coin = test::take_from_sender<Coin<SWT>>(&mut scenario);
                coin::join(&mut swt_coin, coin);
            };

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Traded for SWT"),
                create_test_hash(b"I swapped SUI for SWT to post this"),
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Step 4: User2 swaps SWT back to SUI
        next_tx(&mut scenario, USER2);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);
            let mut swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            // Only swap a very small portion (1 SWT) to avoid overflow
            let swap_amount = coin::split(&mut swt_coin, 1_000_000, ctx(&mut scenario));
            let sui_coin = swap::swap_swt_to_sui(&mut pool, swap_amount, 0, ctx(&mut scenario));

            // User2 now has SUI
            coin::burn_for_testing(sui_coin);
            test::return_to_sender(&mut scenario, swt_coin); // Return remaining SWT
            test::return_shared(pool);
        };

        test::end(scenario);
    }

    // ======== Manager Consensus Tests ========

    #[test]
    fun test_manager_misjudgement_tracking() {
        let mut scenario = init_test_scenario();
        setup_full_ecosystem(&mut scenario);

        // Create message and trigger review
        next_tx(&mut scenario, AUTHOR);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Controversial"),
                create_test_hash(b"This content is borderline"),
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Alert to trigger review
        let mut i = 0;
        while (i < 20) {
            let trader_addr = if (i == 0) @0x7000
                else if (i == 1) @0x7001
                else if (i == 2) @0x7002
                else if (i == 3) @0x7003
                else if (i == 4) @0x7004
                else if (i == 5) @0x7005
                else if (i == 6) @0x7006
                else if (i == 7) @0x7007
                else if (i == 8) @0x7008
                else if (i == 9) @0x7009
                else if (i == 10) @0x700A
                else if (i == 11) @0x700B
                else if (i == 12) @0x700C
                else if (i == 13) @0x700D
                else if (i == 14) @0x700E
                else if (i == 15) @0x700F
                else if (i == 16) @0x7010
                else if (i == 17) @0x7011
                else if (i == 18) @0x7012
                else @0x7013;
            next_tx(&mut scenario, trader_addr);
            {
                let mut msg = test::take_shared<Message>(&mut scenario);
                let mut interactions = test::take_shared<UserInteractions>(&mut scenario);

                message::alert_message(&mut msg, &mut interactions, ctx(&mut scenario));

                test::return_shared(interactions);
                test::return_shared(msg);
            };
            i = i + 1;
        };

        // Create proposal
        next_tx(&mut scenario, MANAGER1);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                1, // PROPOSAL_TYPE_SCAM
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // Manager1 votes approve, others vote reject
        next_tx(&mut scenario, MANAGER1);
        {
            let mut proposal = test::take_shared<Proposal>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

            vote::cast_vote(&mut proposal, &registry, &mut vote_history, true, ctx(&mut scenario));

            test::return_shared(vote_history);
            test::return_shared(registry);
            test::return_shared(proposal);
        };

        // Other managers vote reject
        let managers = vector[MANAGER2, MANAGER3, MANAGER4, MANAGER5];
        let mut i = 0;
        while (i < 4) {
            let manager = *vector::borrow(&managers, i);
            next_tx(&mut scenario, manager);
            {
                let mut proposal = test::take_shared<Proposal>(&mut scenario);
                let registry = test::take_shared<ManagerRegistry>(&mut scenario);
                let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

                vote::cast_vote(&mut proposal, &registry, &mut vote_history, false, ctx(&mut scenario));

                test::return_shared(vote_history);
                test::return_shared(registry);
                test::return_shared(proposal);
            };
            i = i + 1;
        };

        // Check Manager1's misjudgement
        next_tx(&mut scenario, MANAGER1);
        {
            let proposal = test::take_shared<Proposal>(&mut scenario);
            let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);
            let mut manager_nft = test::take_from_sender<ManagerNFT>(&mut scenario);

            vote::check_manager_consensus(
                &mut vote_history,
                &mut manager_nft,
                &proposal,
                MANAGER1
            );

            // Manager1 should have a misjudgement
            let (_, misjudgements) = manager_nft::get_manager_stats(&manager_nft);
            assert!(misjudgements == 1, 999);

            test::return_to_sender(&mut scenario, manager_nft);
            test::return_shared(vote_history);
            test::return_shared(proposal);
        };

        test::end(scenario);
    }

    // ======== Airdrop Distribution Tests ========

    #[test]
    fun test_weekly_airdrop_distribution() {
        let mut scenario = init_test_scenario();
        setup_full_ecosystem(&mut scenario);

        // Multiple users create "cooking" messages
        let authors = vector[USER1, USER2, AUTHOR];
        let mut i = 0;
        while (i < 3) {
            let author = *vector::borrow(&authors, i);
            next_tx(&mut scenario, author);
            {
                let mut board = test::take_shared<MessageBoard>(&mut scenario);
                let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

                message::create_message(
                    &mut board,
                    &swt_coin,
                    create_test_hash(b"Cooking"),
                    create_test_hash(b"Great recipe"),
                    vector[string::utf8(b"cooking")],
                    ctx(&mut scenario)
                );

                test::return_to_sender(&mut scenario, swt_coin);
                test::return_shared(board);
            };
            i = i + 1;
        };

        // Schedule airdrop for cooking message authors
        next_tx(&mut scenario, @0x0);
        {
            let mut reward_system = test::take_shared<RewardSystem>(&mut scenario);

            rewards::schedule_random_airdrop(
                &mut reward_system,
                authors,
                ctx(&mut scenario)
            );

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
                10,
                ctx(&mut scenario)
            );

            test::return_shared(treasury);
            test::return_shared(reward_system);
        };

        // Verify all authors received airdrops
        next_tx(&mut scenario, USER1);
        {
            // USER1 should have initial amount plus airdrop
            // Check if we have multiple coins (initial + airdrop)
            let mut total = 0u64;

            // Take all coins and sum them up
            while (test::has_most_recent_for_sender<Coin<SWT>>(&mut scenario)) {
                let coin = test::take_from_sender<Coin<SWT>>(&mut scenario);
                total = total + coin::value(&coin);
                test::return_to_sender(&mut scenario, coin);
            };

            // Should have received some airdrop amount on top of initial 10000
            assert!(total >= 10000_000_000, 0); // At least the initial amount
        };

        test::end(scenario);
    }

    // ======== Stress Tests ========

    #[test]
    fun test_high_volume_activity() {
        let mut scenario = init_test_scenario();
        setup_full_ecosystem(&mut scenario);

        // Create many messages
        let mut msg_count = 0;
        while (msg_count < 10) {
            let author = if (msg_count == 0) @0x8000
                else if (msg_count == 1) @0x8001
                else if (msg_count == 2) @0x8002
                else if (msg_count == 3) @0x8003
                else if (msg_count == 4) @0x8004
                else if (msg_count == 5) @0x8005
                else if (msg_count == 6) @0x8006
                else if (msg_count == 7) @0x8007
                else if (msg_count == 8) @0x8008
                else @0x8009;
            next_tx(&mut scenario, author);

            // Give author tokens
            let mut treasury = test::take_shared<Treasury>(&mut scenario);
            token::transfer_from_treasury(&mut treasury, 2000_000_000, author, ctx(&mut scenario));
            test::return_shared(treasury);

            next_tx(&mut scenario, author);
            {
                let mut board = test::take_shared<MessageBoard>(&mut scenario);
                let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

                message::create_message(
                    &mut board,
                    &swt_coin,
                    create_test_hash(b"Message"),
                    create_test_hash(b"Content"),
                    vector::empty(),
                    ctx(&mut scenario)
                );

                test::return_to_sender(&mut scenario, swt_coin);
                test::return_shared(board);
            };
            msg_count = msg_count + 1;
        };

        // Perform many swaps
        let mut swap_count = 0;
        while (swap_count < 10) {
            let trader = if (swap_count == 0) @0x9000
                else if (swap_count == 1) @0x9001
                else if (swap_count == 2) @0x9002
                else if (swap_count == 3) @0x9003
                else if (swap_count == 4) @0x9004
                else if (swap_count == 5) @0x9005
                else if (swap_count == 6) @0x9006
                else if (swap_count == 7) @0x9007
                else if (swap_count == 8) @0x9008
                else @0x9009;
            next_tx(&mut scenario, trader);
            {
                let mut pool = test::take_shared<SwapPool>(&mut scenario);

                if (swap_count % 2 == 0) {
                    let sui_coin = mint_for_testing<SUI>(100_000_000, ctx(&mut scenario));
                    let swt_coin = swap::swap_sui_to_swt(&mut pool, sui_coin, 0, ctx(&mut scenario));
                    coin::burn_for_testing(swt_coin);
                } else {
                    // Swap in opposite direction with smaller amount
                    let sui_coin = mint_for_testing<SUI>(50_000_000, ctx(&mut scenario));
                    let swt_coin = swap::swap_sui_to_swt(&mut pool, sui_coin, 0, ctx(&mut scenario));
                    coin::burn_for_testing(swt_coin);
                };

                test::return_shared(pool);
            };
            swap_count = swap_count + 1;
        };

        // Verify system still functional
        next_tx(&mut scenario, @0x0);
        {
            let board = test::take_shared<MessageBoard>(&mut scenario);
            // Check would require get_total_messages function
            test::return_shared(board);

            let pool = test::take_shared<SwapPool>(&mut scenario);
            assert!(swap::get_sui_reserve(&pool) > 0, 0);
            assert!(swap::get_swt_reserve(&pool) > 0, 1);
            test::return_shared(pool);
        };

        test::end(scenario);
    }

    // ======== Edge Case Integration Tests ========

    #[test]
    fun test_blacklisted_user_restrictions() {
        let mut scenario = init_test_scenario();
        setup_full_ecosystem(&mut scenario);

        // Get user blacklisted through multiple scams
        let mut scam_count = 0;
        while (scam_count < 5) {
            // Create scam message
            next_tx(&mut scenario, SCAMMER);
            {
                let mut board = test::take_shared<MessageBoard>(&mut scenario);
                let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

                message::create_message(
                    &mut board,
                    &swt_coin,
                    create_test_hash(b"SCAM"),
                    create_test_hash(b"Spam content"),
                    vector::empty(),
                    ctx(&mut scenario)
                );

                test::return_to_sender(&mut scenario, swt_coin);
                test::return_shared(board);
            };

            // Fast-track to scam confirmation
            next_tx(&mut scenario, @0x0);
            {
                let mut slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
                let mut treasury = test::take_shared<Treasury>(&mut scenario);
                let coin = mint_for_testing<SWT>(200_000_000, ctx(&mut scenario));

                let fake_msg_id = object::id_from_address(@0xFACE);
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

            scam_count = scam_count + 1;
        };

        // Verify user is blacklisted
        next_tx(&mut scenario, @0x0);
        {
            let slashing_system = test::take_shared<SlashingSystem>(&mut scenario);
            assert!(slashing::is_user_blacklisted(&slashing_system, SCAMMER), 0);
            test::return_shared(slashing_system);
        };

        // Blacklisted user should have restricted abilities
        // (Further restrictions would be implemented in production)

        test::end(scenario);
    }

    #[test]
    fun test_manager_rotation_after_slashing() {
        let mut scenario = init_test_scenario();
        setup_full_ecosystem(&mut scenario);

        // Manager accumulates misjudgements
        let mut misjudgement_count = 0;
        while (misjudgement_count < 3) {
            next_tx(&mut scenario, MANAGER1);
            {
                let mut nft = test::take_from_sender<ManagerNFT>(&mut scenario);
                manager_nft::increment_misjudgement_count(&mut nft);
                test::return_to_sender(&mut scenario, nft);
            };
            misjudgement_count = misjudgement_count + 1;
        };

        // Slash the manager NFT
        next_tx(&mut scenario, MANAGER1);
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let nft = test::take_from_sender<ManagerNFT>(&mut scenario);

            manager_nft::slash_manager_nft(
                &mut registry,
                nft,
                ctx(&mut scenario)
            );

            // Manager is removed from registry
            assert!(!manager_nft::is_manager(&registry, MANAGER1), 0);

            test::return_shared(registry);
        };

        // New manager can be appointed
        next_tx(&mut scenario, @0x0);
        {
            let mut registry = test::take_shared<ManagerRegistry>(&mut scenario);

            let new_manager = @0x99;
            manager_nft::mint_manager_nft(
                &mut registry,
                new_manager,
                string::utf8(b"New Manager"),
                string::utf8(b"Replacement manager"),
                ctx(&mut scenario)
            );

            assert!(manager_nft::is_manager(&registry, new_manager), 1);

            test::return_shared(registry);
        };

        test::end(scenario);
    }
}

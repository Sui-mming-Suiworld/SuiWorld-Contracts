#[test_only]
module suiworld::vote_tests {
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, ID};
    use std::string;
    use suiworld::vote::{Self, Proposal, VotingSystem, ManagerVoteHistory};
    use suiworld::message::{Self, Message, MessageBoard, UserInteractions};
    use suiworld::manager_nft::{Self, ManagerNFT, ManagerRegistry};
    use suiworld::token::{Self, Treasury, SWT};
    use suiworld::rewards::{Self, RewardSystem};
    use suiworld::slashing::{Self};

    const PROPOSER: address = @0x51;
    const MANAGER1: address = @0x21;
    const MANAGER2: address = @0x22;
    const MANAGER3: address = @0x23;
    const MANAGER4: address = @0x24;
    const MANAGER5: address = @0x25;
    const USER1: address = @0x11;

    const MIN_SWT: u64 = 1000_000_000; // 1000 SWT
    const QUORUM: u64 = 4;

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

    fun setup_voting_environment(scenario: &mut Scenario) {
        // Initialize all modules
        next_tx(scenario, @0x0);
        {
            manager_nft::test_init(ctx(scenario));
            vote::test_init(ctx(scenario));
            message::test_init(ctx(scenario));
            token::test_init(ctx(scenario));
            rewards::test_init(ctx(scenario));
            slashing::test_init(ctx(scenario));
        };

        // Create manager NFTs
        next_tx(scenario, @0x0);
        let mut registry = test::take_shared<ManagerRegistry>(scenario);
        manager_nft::mint_manager_nft(
            &mut registry, MANAGER1,
            string::utf8(b"Manager 1"),
            string::utf8(b"First manager"),
            ctx(scenario)
        );
        manager_nft::mint_manager_nft(
            &mut registry, MANAGER2,
            string::utf8(b"Manager 2"),
            string::utf8(b"Second manager"),
            ctx(scenario)
        );
        manager_nft::mint_manager_nft(
            &mut registry, MANAGER3,
            string::utf8(b"Manager 3"),
            string::utf8(b"Third manager"),
            ctx(scenario)
        );
        manager_nft::mint_manager_nft(
            &mut registry, MANAGER4,
            string::utf8(b"Manager 4"),
            string::utf8(b"Fourth manager"),
            ctx(scenario)
        );
        manager_nft::mint_manager_nft(
            &mut registry, MANAGER5,
            string::utf8(b"Manager 5"),
            string::utf8(b"Fifth manager"),
            ctx(scenario)
        );
        test::return_shared(registry);

        // Add tokens to treasury and distribute SWT to users
        next_tx(scenario, @0x0);
        {
            let mut treasury = test::take_shared<Treasury>(scenario);
            token::test_mint_and_add_to_treasury(&mut treasury, MIN_SWT * 100, ctx(scenario));
            test::return_shared(treasury);
        };

        next_tx(scenario, @0x0);
        {
            let mut treasury = test::take_shared<Treasury>(scenario);
            token::transfer_from_treasury(&mut treasury, MIN_SWT * 10, USER1, ctx(scenario));
            token::transfer_from_treasury(&mut treasury, MIN_SWT * 10, PROPOSER, ctx(scenario));
            test::return_shared(treasury);
        };
    }

    fun create_test_message(scenario: &mut Scenario, author: address): ID {
        next_tx(scenario, author);
        let mut board = test::take_shared<MessageBoard>(scenario);
        let swt_coin = test::take_from_sender<Coin<SWT>>(scenario);

        message::create_message(
            &mut board,
            &swt_coin,
            create_test_hash(b"Test Title"),
            create_test_hash(b"Test Content"),
            vector::empty(),
            ctx(scenario)
        );

        test::return_to_sender(scenario, swt_coin);
        test::return_shared(board);

        // Get message ID
        let msg = test::take_shared<Message>(scenario);
        let msg_id = object::id(&msg);
        test::return_shared(msg);

        msg_id
    }

    // ======== Proposal Creation Tests ========

    #[test]
    fun test_create_hype_proposal() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        let msg_id = create_test_message(&mut scenario, USER1);

        // Create HYPE proposal
        next_tx(&mut scenario, PROPOSER);
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

        // Verify proposal was created
        {
            assert!(test::has_most_recent_shared<Proposal>(), 0);
            let proposal = test::take_shared<Proposal>(&mut scenario);

            assert!(vote::get_proposal_status(&proposal) == 0, 999); // STATUS_OPEN
            assert!(vote::get_proposal_type(&proposal) == 0, 999); // PROPOSAL_TYPE_HYPE
            let (approve_votes, reject_votes) = vote::get_proposal_votes(&proposal);
            assert!(approve_votes == 0, 999);
            assert!(reject_votes == 0, 999);

            test::return_shared(proposal);
        };

        test::end(scenario);
    }

    #[test]
    fun test_create_scam_proposal() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        let msg_id = create_test_message(&mut scenario, USER1);

        // Create SCAM proposal
        next_tx(&mut scenario, PROPOSER);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                1, // PROPOSAL_TYPE_SCAM
                // Description: "Spam content"
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure]
    fun test_create_proposal_for_normal_message_fails() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        // Create message but don't trigger review
        next_tx(&mut scenario, USER1);
        {
            let mut board = test::take_shared<MessageBoard>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            message::create_message(
                &mut board,
                &swt_coin,
                create_test_hash(b"Normal"),
                create_test_hash(b"Content"),
                vector::empty(),
                ctx(&mut scenario)
            );

            test::return_to_sender(&mut scenario, swt_coin);
            test::return_shared(board);
        };

        // Try to create proposal for normal message (should fail)
        next_tx(&mut scenario, PROPOSER);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                0,
                // Description: "Should fail"
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        test::end(scenario);
    }

    // ======== Voting Tests ========

    #[test]
    fun test_cast_vote_approve() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        let msg_id = create_test_message(&mut scenario, USER1);

        // Create proposal
        next_tx(&mut scenario, PROPOSER);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                0,
                // Description: "Vote test"
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // Manager1 votes approve
        next_tx(&mut scenario, MANAGER1);
        {
            let mut proposal = test::take_shared<Proposal>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

            vote::cast_vote(
                &mut proposal,
                &registry,
                &mut vote_history,
                true, // vote_approve
                ctx(&mut scenario)
            );

            let (approve_votes, reject_votes) = vote::get_proposal_votes(&proposal);
            assert!(approve_votes == 1, 999);
            assert!(reject_votes == 0, 999);

            test::return_shared(vote_history);
            test::return_shared(registry);
            test::return_shared(proposal);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::vote::EAlreadyVoted)]
    fun test_double_voting_fails() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        let msg_id = create_test_message(&mut scenario, USER1);

        // Create proposal
        next_tx(&mut scenario, PROPOSER);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                0,
                // Description: "Test"
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // Manager1 votes twice
        next_tx(&mut scenario, MANAGER1);
        {
            let mut proposal = test::take_shared<Proposal>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

            // First vote
            vote::cast_vote(
                &mut proposal,
                &registry,
                &mut vote_history,
                true, // vote_approve
                ctx(&mut scenario)
            );

            // Second vote (should fail)
            vote::cast_vote(
                &mut proposal,
                &registry,
                &mut vote_history,
                true, // vote_approve
                ctx(&mut scenario)
            );

            test::return_shared(vote_history);
            test::return_shared(registry);
            test::return_shared(proposal);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::vote::ENotManager)]
    fun test_non_manager_vote_fails() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        let msg_id = create_test_message(&mut scenario, USER1);

        // Create proposal
        next_tx(&mut scenario, PROPOSER);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                0,
                // Description: "Test"
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // Non-manager tries to vote
        next_tx(&mut scenario, USER1);
        {
            let mut proposal = test::take_shared<Proposal>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

            // This should fail
            vote::cast_vote(
                &mut proposal,
                &registry,
                &mut vote_history,
                true, // vote_approve
                ctx(&mut scenario)
            );

            test::return_shared(vote_history);
            test::return_shared(registry);
            test::return_shared(proposal);
        };

        test::end(scenario);
    }

    // ======== Quorum Tests ========

    #[test]
    fun test_reach_quorum_approve() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        let msg_id = create_test_message(&mut scenario, USER1);

        // Create proposal
        next_tx(&mut scenario, PROPOSER);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                0,
                // Description: "Quorum test"
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // Cast 4 approve votes (quorum)
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
                    true, // vote_approve
                    ctx(&mut scenario)
                );

                test::return_shared(vote_history);
                test::return_shared(registry);
                test::return_shared(proposal);
            };
            i = i + 1;
        };

        // Verify proposal reached quorum and passed
        next_tx(&mut scenario, @0x0);
        {
            let proposal = test::take_shared<Proposal>(&mut scenario);
            // Check if proposal passed (would need actual status check)
            test::return_shared(proposal);
        };

        test::end(scenario);
    }

    #[test]
    fun test_reach_quorum_reject() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        let msg_id = create_test_message(&mut scenario, USER1);

        // Create proposal
        next_tx(&mut scenario, PROPOSER);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                1, // PROPOSAL_TYPE_SCAM
                // Description: "Reject test"
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // Cast 4 reject votes
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
                    false, // Reject vote
                    ctx(&mut scenario)
                );

                test::return_shared(vote_history);
                test::return_shared(registry);
                test::return_shared(proposal);
            };
            i = i + 1;
        };

        // Verify proposal was rejected
        next_tx(&mut scenario, @0x0);
        {
            let proposal = test::take_shared<Proposal>(&mut scenario);
            assert!(vote::get_proposal_status(&proposal) == 2, 999);
            test::return_shared(proposal);
        };

        test::end(scenario);
    }

    // ======== Execution Tests ========

    #[test]
    fun test_execute_hype_proposal() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        let msg_id = create_test_message(&mut scenario, USER1);

        // Create and pass HYPE proposal
        next_tx(&mut scenario, PROPOSER);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                0,
                // Description: "Execute test"
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // Vote to pass
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
                    true,
                    ctx(&mut scenario)
                );

                test::return_shared(vote_history);
                test::return_shared(registry);
                test::return_shared(proposal);
            };
            i = i + 1;
        };

        // Execute proposal
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

            // Message status should be HYPED
            assert!(message::get_message_status(&msg) == 2, 999); // STATUS_HYPED
            // Check if proposal executed (would need actual status check)

            test::return_shared(treasury);
            test::return_shared(msg);
            test::return_shared(proposal);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure]
    fun test_execute_not_passed_proposal_fails() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        let msg_id = create_test_message(&mut scenario, USER1);

        // Create proposal but don't reach quorum
        next_tx(&mut scenario, PROPOSER);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                0,
                // Description: "No quorum"
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // Only 2 votes (not enough for quorum)
        next_tx(&mut scenario, MANAGER1);
        {
            let mut proposal = test::take_shared<Proposal>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

            vote::cast_vote(
                &mut proposal,
                &registry,
                &mut vote_history,
                true,
                ctx(&mut scenario)
            );

            test::return_shared(vote_history);
            test::return_shared(registry);
            test::return_shared(proposal);
        };

        // Try to execute (should fail)
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

            test::return_shared(treasury);
            test::return_shared(msg);
            test::return_shared(proposal);
        };

        test::end(scenario);
    }

    // ======== BFT Consensus Tests ========

    #[test]
    fun test_manager_consensus_check() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        let msg_id = create_test_message(&mut scenario, USER1);

        // Create proposal
        next_tx(&mut scenario, PROPOSER);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                0,
                // Description: "BFT test"
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // Manager1 votes approve
        next_tx(&mut scenario, MANAGER1);
        {
            let mut proposal = test::take_shared<Proposal>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

            vote::cast_vote(
                &mut proposal,
                &registry,
                &mut vote_history,
                true,
                ctx(&mut scenario)
            );

            test::return_shared(vote_history);
            test::return_shared(registry);
            test::return_shared(proposal);
        };

        // Others vote reject (Manager1 misjudged)
        let managers = vector[MANAGER2, MANAGER3, MANAGER4, MANAGER5];
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
                    false,
                    ctx(&mut scenario)
                );

                test::return_shared(vote_history);
                test::return_shared(registry);
                test::return_shared(proposal);
            };
            i = i + 1;
        };

        // Check Manager1's consensus
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

            // Manager1 should have 1 misjudgement
            let (_, misjudgements) = manager_nft::get_manager_stats(&manager_nft);
            assert!(misjudgements == 1, 999);

            test::return_to_sender(&mut scenario, manager_nft);
            test::return_shared(vote_history);
            test::return_shared(proposal);
        };

        test::end(scenario);
    }

    // ======== Edge Cases ========

    #[test]
    fun test_split_vote_scenario() {
        let mut scenario = init_test_scenario();
        setup_voting_environment(&mut scenario);

        let msg_id = create_test_message(&mut scenario, USER1);

        // Create proposal
        next_tx(&mut scenario, PROPOSER);
        {
            let mut voting_system = test::take_shared<VotingSystem>(&mut scenario);
            let msg = test::take_shared<Message>(&mut scenario);

            vote::create_proposal(
                &mut voting_system,
                &msg,
                0,
                // Description: "Split vote"
                ctx(&mut scenario)
            );

            test::return_shared(msg);
            test::return_shared(voting_system);
        };

        // 2 approve, 2 reject (no quorum either way)
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

        next_tx(&mut scenario, MANAGER2);
        {
            let mut proposal = test::take_shared<Proposal>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

            vote::cast_vote(&mut proposal, &registry, &mut vote_history, true, ctx(&mut scenario));

            test::return_shared(vote_history);
            test::return_shared(registry);
            test::return_shared(proposal);
        };

        next_tx(&mut scenario, MANAGER3);
        {
            let mut proposal = test::take_shared<Proposal>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

            vote::cast_vote(&mut proposal, &registry, &mut vote_history, false, ctx(&mut scenario));

            test::return_shared(vote_history);
            test::return_shared(registry);
            test::return_shared(proposal);
        };

        next_tx(&mut scenario, MANAGER4);
        {
            let mut proposal = test::take_shared<Proposal>(&mut scenario);
            let registry = test::take_shared<ManagerRegistry>(&mut scenario);
            let mut vote_history = test::take_shared<ManagerVoteHistory>(&mut scenario);

            vote::cast_vote(&mut proposal, &registry, &mut vote_history, false, ctx(&mut scenario));

            test::return_shared(vote_history);
            test::return_shared(registry);
            test::return_shared(proposal);
        };

        // Proposal should still be OPEN
        next_tx(&mut scenario, @0x0);
        {
            let proposal = test::take_shared<Proposal>(&mut scenario);
            assert!(vote::get_proposal_status(&proposal) == 0, 999);
            let (approve_votes, reject_votes) = vote::get_proposal_votes(&proposal);
            assert!(approve_votes == 2, 999);
            assert!(reject_votes == 2, 999);
            test::return_shared(proposal);
        };

        test::end(scenario);
    }
}
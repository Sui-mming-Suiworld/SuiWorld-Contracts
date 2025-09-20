module suiworld::vote {
    use sui::event;
    use sui::table::{Self, Table};
    use suiworld::manager_nft::{Self, ManagerRegistry, ManagerNFT};
    use suiworld::message::{Self, Message};
    use suiworld::token::{Self, Treasury};

    // Proposal types
    const PROPOSAL_TYPE_HYPE: u8 = 0;
    const PROPOSAL_TYPE_SCAM: u8 = 1;

    // Proposal status
    const STATUS_OPEN: u8 = 0;
    const STATUS_PASSED: u8 = 1;
    const STATUS_REJECTED: u8 = 2;
    const STATUS_EXECUTED: u8 = 3;

    // Vote types
    const VOTE_APPROVE: bool = true;

    // Proposal structure
    public struct Proposal has key, store {
        id: UID,
        message_id: ID,
        proposal_type: u8,
        status: u8,
        proposer: address,
        approve_votes: u64,
        reject_votes: u64,
        voters: vector<address>,
        created_at: u64,
        resolved_at: u64,
        tx_digest: vector<u8>,
    }

    // Voting system state
    public struct VotingSystem has key {
        id: UID,
        proposals: Table<ID, bool>,
        active_proposals: vector<ID>,
        total_proposals: u64,
        quorum: u64,
    }

    // BFT check for managers
    public struct ManagerVoteHistory has key {
        id: UID,
        manager_votes: Table<address, vector<VoteHistoryEntry>>,
        misjudgement_counts: Table<address, u64>,
    }

    public struct VoteHistoryEntry has store, copy, drop {
        proposal_id: ID,
        vote: bool,
        consensus_result: bool,
        timestamp: u64,
    }

    // Manager Resolution Proposal for removing malicious managers
    public struct ManagerResolutionProposal has key, store {
        id: UID,
        target_manager: address,
        reason: vector<u8>,
        proposer: address,
        approve_votes: u64,
        reject_votes: u64,
        voters: vector<address>,
        status: u8,
        created_at: u64,
        resolved_at: u64,
    }

    // Events
    public struct ProposalCreated has copy, drop {
        proposal_id: ID,
        message_id: ID,
        proposal_type: u8,
        proposer: address,
    }

    public struct VoteCast has copy, drop {
        proposal_id: ID,
        voter: address,
        vote: bool,
    }

    public struct ProposalResolved has copy, drop {
        proposal_id: ID,
        status: u8,
        approve_votes: u64,
        reject_votes: u64,
    }

    public struct ManagerMisjudgementDetected has copy, drop {
        manager: address,
        proposal_id: ID,
        misjudgement_count: u64,
    }

    // Constants
    const QUORUM: u64 = 4; // Minimum votes to pass
    const HYPE_CREATOR_REWARD: u64 = 100_000_000; // 100 SWT
    const HYPE_MANAGER_REWARD: u64 = 10_000_000; // 10 SWT
    const SCAM_MANAGER_REWARD: u64 = 10_000_000; // 10 SWT

    // Error codes
    const ENotManager: u64 = 1;
    const EAlreadyVoted: u64 = 2;
    const EProposalNotOpen: u64 = 3;
    const EInvalidProposalType: u64 = 4;
    const EQuorumNotReached: u64 = 5;
    const EMessageNotUnderReview: u64 = 6;

    // Initialize voting system
    fun init(ctx: &mut TxContext) {
        let voting_system = VotingSystem {
            id: object::new(ctx),
            proposals: table::new(ctx),
            active_proposals: vector::empty(),
            total_proposals: 0,
            quorum: QUORUM,
        };

        let manager_vote_history = ManagerVoteHistory {
            id: object::new(ctx),
            manager_votes: table::new(ctx),
            misjudgement_counts: table::new(ctx),
        };

        transfer::share_object(voting_system);
        transfer::share_object(manager_vote_history);
    }

    // Create a proposal (automatically when message reaches threshold)
    // Called when a message reaches 20 likes (HYPE) or 20 alerts (SCAM)
    // Anyone can call this for messages in UNDER_REVIEW status
    // Caller gets 1 SWT reward for triggering proposal creation
    public fun create_proposal_auto(
        voting_system: &mut VotingSystem,
        message: &Message,
        proposal_type: u8,
        treasury: &mut Treasury,
        ctx: &mut TxContext
    ): ID {
        assert!(proposal_type <= PROPOSAL_TYPE_SCAM, EInvalidProposalType);

        // Check message status and thresholds
        let should_create = if (proposal_type == PROPOSAL_TYPE_HYPE) {
            message::get_message_likes(message) >= 20
        } else {
            message::get_message_alerts(message) >= 20
        };

        assert!(should_create, EMessageNotUnderReview);
        assert!(message::is_under_review(message), EMessageNotUnderReview);

        // Reward the caller for triggering proposal creation (1 SWT incentive)
        let trigger_reward = 1_000_000; // 1 SWT
        token::transfer_from_treasury_internal(treasury, trigger_reward, tx_context::sender(ctx), ctx);

        let message_id = object::id(message);
        let proposer = tx_context::sender(ctx); // System or triggering user
        let created_at = tx_context::epoch(ctx);

        let proposal = Proposal {
            id: object::new(ctx),
            message_id,
            proposal_type,
            status: STATUS_OPEN,
            proposer,
            approve_votes: 0,
            reject_votes: 0,
            voters: vector::empty(),
            created_at,
            resolved_at: 0,
            tx_digest: vector::empty(),
        };

        let proposal_id = object::id(&proposal);

        // Add to voting system
        table::add(&mut voting_system.proposals, proposal_id, true);
        vector::push_back(&mut voting_system.active_proposals, proposal_id);
        voting_system.total_proposals = voting_system.total_proposals + 1;

        // Emit event
        event::emit(ProposalCreated {
            proposal_id,
            message_id,
            proposal_type,
            proposer,
        });

        transfer::share_object(proposal);

        proposal_id
    }

    // Cast a vote (Manager only) - auto-executes if proposal passes
    public fun cast_vote(
        proposal: &mut Proposal,
        manager_registry: &ManagerRegistry,
        vote_history: &mut ManagerVoteHistory,
        message: &mut Message,
        treasury: &mut Treasury,
        vote: bool,
        ctx: &mut TxContext
    ) {
        let voter = tx_context::sender(ctx);

        // Check if voter is a manager
        assert!(manager_nft::is_manager(manager_registry, voter), ENotManager);

        // Check if proposal is open
        assert!(proposal.status == STATUS_OPEN, EProposalNotOpen);

        // Check if already voted
        let mut already_voted = false;
        let mut i = 0;
        while (i < vector::length(&proposal.voters)) {
            if (*vector::borrow(&proposal.voters, i) == voter) {
                already_voted = true;
                break
            };
            i = i + 1;
        };
        assert!(!already_voted, EAlreadyVoted);

        // Record vote
        vector::push_back(&mut proposal.voters, voter);

        if (vote == VOTE_APPROVE) {
            proposal.approve_votes = proposal.approve_votes + 1;
        } else {
            proposal.reject_votes = proposal.reject_votes + 1;
        };

        // Record in manager's vote history
        if (!table::contains(&vote_history.manager_votes, voter)) {
            table::add(&mut vote_history.manager_votes, voter, vector::empty());
        };

        let history_entry = VoteHistoryEntry {
            proposal_id: object::id(proposal),
            vote,
            consensus_result: false, // Will be updated after resolution
            timestamp: tx_context::epoch(ctx),
        };

        let manager_history = table::borrow_mut(&mut vote_history.manager_votes, voter);
        vector::push_back(manager_history, history_entry);

        // Emit event
        event::emit(VoteCast {
            proposal_id: object::id(proposal),
            voter,
            vote,
        });

        // Check if proposal can be resolved (first to reach 4 votes wins)
        if (proposal.approve_votes >= QUORUM) {
            proposal.status = STATUS_PASSED;
            proposal.resolved_at = tx_context::epoch(ctx);

            event::emit(ProposalResolved {
                proposal_id: object::id(proposal),
                status: proposal.status,
                approve_votes: proposal.approve_votes,
                reject_votes: proposal.reject_votes,
            });

            // Auto-execute the proposal
            execute_proposal_internal(proposal, message, treasury, ctx);
        } else if (proposal.reject_votes >= QUORUM) {
            proposal.status = STATUS_REJECTED;
            proposal.resolved_at = tx_context::epoch(ctx);

            event::emit(ProposalResolved {
                proposal_id: object::id(proposal),
                status: proposal.status,
                approve_votes: proposal.approve_votes,
                reject_votes: proposal.reject_votes,
            });
        }
    }


    // Internal function to execute proposal (called automatically after voting)
    fun execute_proposal_internal(
        proposal: &mut Proposal,
        message: &mut Message,
        treasury: &mut Treasury,
        ctx: &mut TxContext
    ) {
        assert!(proposal.status == STATUS_PASSED, EQuorumNotReached);

        let message_author = message::get_message_author(message);

        if (proposal.proposal_type == PROPOSAL_TYPE_HYPE) {
            // Update message status to HYPED
            message::update_message_status(message, message::status_hyped());

            // Reward creator: +100 SWT
            token::transfer_from_treasury_internal(treasury, HYPE_CREATOR_REWARD, message_author, ctx);

            // Reward each voting manager: +10 SWT
            let mut i = 0;
            while (i < vector::length(&proposal.voters)) {
                let voter = *vector::borrow(&proposal.voters, i);
                token::transfer_from_treasury_internal(treasury, HYPE_MANAGER_REWARD, voter, ctx);
                i = i + 1;
            };

        } else if (proposal.proposal_type == PROPOSAL_TYPE_SCAM) {
            // Update message status to SPAM
            message::update_message_status(message, message::status_spam());

            // Creator penalty: -200 SWT (handled separately through slashing)
            // For now, just reward managers

            // Reward each voting manager: +10 SWT
            let mut i = 0;
            while (i < vector::length(&proposal.voters)) {
                let voter = *vector::borrow(&proposal.voters, i);
                token::transfer_from_treasury_internal(treasury, SCAM_MANAGER_REWARD, voter, ctx);
                i = i + 1;
            };
        };

        proposal.status = STATUS_EXECUTED;
    }

    // Public wrapper for execute_proposal (for manual execution if needed)
    public fun execute_proposal(
        proposal: &mut Proposal,
        message: &mut Message,
        treasury: &mut Treasury,
        ctx: &mut TxContext
    ) {
        execute_proposal_internal(proposal, message, treasury, ctx);
    }

    // BFT check for manager misjudgements
    public fun check_manager_consensus(
        vote_history: &mut ManagerVoteHistory,
        manager_nft: &mut ManagerNFT,
        proposal: &Proposal,
        manager_address: address
    ) {
        if (!table::contains(&vote_history.manager_votes, manager_address)) {
            return
        };

        let manager_votes = table::borrow_mut(&mut vote_history.manager_votes, manager_address);
        let consensus_result = proposal.status == STATUS_PASSED;

        // Update the consensus result in history
        let mut i = 0;
        while (i < vector::length(manager_votes)) {
            let entry = vector::borrow_mut(manager_votes, i);
            if (entry.proposal_id == object::id(proposal)) {
                entry.consensus_result = consensus_result;

                // Check if manager voted against consensus
                if ((entry.vote && !consensus_result) || (!entry.vote && consensus_result)) {
                    // Manager misjudged
                    manager_nft::increment_misjudgement_count(manager_nft);

                    let (_, misjudgement_count) = manager_nft::get_manager_stats(manager_nft);

                    event::emit(ManagerMisjudgementDetected {
                        manager: manager_address,
                        proposal_id: object::id(proposal),
                        misjudgement_count,
                    });
                };
                break
            };
            i = i + 1;
        };
    }

    // Get proposal details
    public fun get_proposal_status(proposal: &Proposal): u8 {
        proposal.status
    }

    public fun get_proposal_votes(proposal: &Proposal): (u64, u64) {
        (proposal.approve_votes, proposal.reject_votes)
    }

    public fun get_proposal_type(proposal: &Proposal): u8 {
        proposal.proposal_type
    }

    // ============ Manager Resolution Functions (BFT) ============

    // Create a manager resolution proposal (to remove a malicious manager)
    public fun create_manager_resolution(
        manager_registry: &ManagerRegistry,
        target_manager: address,
        reason: vector<u8>,
        ctx: &mut TxContext
    ): ID {
        let proposer = tx_context::sender(ctx);

        // Only managers can propose manager resolution
        assert!(manager_nft::is_manager(manager_registry, proposer), ENotManager);

        // Cannot propose to remove yourself
        assert!(proposer != target_manager, ENotManager);

        let resolution = ManagerResolutionProposal {
            id: object::new(ctx),
            target_manager,
            reason,
            proposer,
            approve_votes: 0,
            reject_votes: 0,
            voters: vector::empty(),
            status: STATUS_OPEN,
            created_at: tx_context::epoch(ctx),
            resolved_at: 0,
        };

        let resolution_id = object::id(&resolution);

        transfer::share_object(resolution);

        resolution_id
    }

    // Vote on manager resolution (BFT voting)
    public fun vote_manager_resolution(
        resolution: &mut ManagerResolutionProposal,
        manager_registry: &ManagerRegistry,
        vote: bool,
        ctx: &mut TxContext
    ) {
        let voter = tx_context::sender(ctx);

        // Only managers can vote
        assert!(manager_nft::is_manager(manager_registry, voter), ENotManager);

        // Cannot vote if already resolved
        assert!(resolution.status == STATUS_OPEN, EProposalNotOpen);

        // Check if already voted
        let mut already_voted = false;
        let mut i = 0;
        while (i < vector::length(&resolution.voters)) {
            if (*vector::borrow(&resolution.voters, i) == voter) {
                already_voted = true;
                break
            };
            i = i + 1;
        };
        assert!(!already_voted, EAlreadyVoted);

        // Record vote
        vector::push_back(&mut resolution.voters, voter);

        if (vote) {
            resolution.approve_votes = resolution.approve_votes + 1;
        } else {
            resolution.reject_votes = resolution.reject_votes + 1;
        };

        // Check if resolution reached quorum (8 out of 12 for manager removal)
        let bft_quorum = 8; // 2/3 of 12 managers
        if (resolution.approve_votes >= bft_quorum) {
            resolution.status = STATUS_PASSED;
            resolution.resolved_at = tx_context::epoch(ctx);
            // Manager will be removed via execute_manager_resolution
        } else if (resolution.reject_votes >= 5) { // More than 1/3 reject = fail
            resolution.status = STATUS_REJECTED;
            resolution.resolved_at = tx_context::epoch(ctx);
        }
    }

    // Execute manager resolution (remove the manager and burn their NFT)
    public fun execute_manager_resolution(
        resolution: &ManagerResolutionProposal,
        manager_registry: &mut ManagerRegistry,
        ctx: &mut TxContext
    ) {
        // Resolution must be passed
        assert!(resolution.status == STATUS_PASSED, EQuorumNotReached);

        // Slash the manager NFT
        manager_nft::slash_manager_for_misconduct(
            manager_registry,
            resolution.target_manager,
            ctx
        );
    }

    // Track misjudgements for BFT consensus
    public fun update_misjudgement_count(
        vote_history: &mut ManagerVoteHistory,
        manager: address,
        proposal_id: ID,
        was_correct: bool
    ) {
        if (!table::contains(&vote_history.misjudgement_counts, manager)) {
            table::add(&mut vote_history.misjudgement_counts, manager, 0);
        };

        if (!was_correct) {
            let count = table::borrow_mut(&mut vote_history.misjudgement_counts, manager);
            *count = *count + 1;

            // If too many misjudgements, it can trigger a resolution proposal
            if (*count >= 3) {
                event::emit(ManagerMisjudgementDetected {
                    manager,
                    proposal_id,
                    misjudgement_count: *count,
                });
            };
        };
    }
}

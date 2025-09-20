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
    }

    public struct VoteHistoryEntry has store, copy, drop {
        proposal_id: ID,
        vote: bool,
        consensus_result: bool,
        timestamp: u64,
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
        };

        transfer::share_object(voting_system);
        transfer::share_object(manager_vote_history);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    // Create a proposal (automatically when message reaches threshold)
    public fun create_proposal(
        voting_system: &mut VotingSystem,
        message: &Message,
        proposal_type: u8,
        ctx: &mut TxContext
    ): ID {
        assert!(proposal_type <= PROPOSAL_TYPE_SCAM, EInvalidProposalType);

        // Only allow proposals for messages under review
        assert!(message::is_under_review(message), EMessageNotUnderReview);

        let message_id = object::id(message);
        let proposer = tx_context::sender(ctx);
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

    // Cast a vote (Manager only)
    public fun cast_vote(
        proposal: &mut Proposal,
        manager_registry: &ManagerRegistry,
        vote_history: &mut ManagerVoteHistory,
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

        // Check if proposal can be resolved
        if (proposal.approve_votes >= QUORUM || proposal.reject_votes >= QUORUM) {
            resolve_proposal(proposal, ctx);
        }
    }

    // Resolve proposal
    fun resolve_proposal(proposal: &mut Proposal, ctx: &TxContext) {
        if (proposal.approve_votes >= QUORUM) {
            proposal.status = STATUS_PASSED;
        } else if (proposal.reject_votes >= QUORUM) {
            proposal.status = STATUS_REJECTED;
        } else {
            return // Not enough votes yet
        };

        proposal.resolved_at = tx_context::epoch(ctx);

        event::emit(ProposalResolved {
            proposal_id: object::id(proposal),
            status: proposal.status,
            approve_votes: proposal.approve_votes,
            reject_votes: proposal.reject_votes,
        });
    }

    // Execute proposal (apply rewards/penalties)
    public fun execute_proposal(
        proposal: &mut Proposal,
        message: &mut Message,
        treasury: &mut Treasury,
        ctx: &mut TxContext
    ) {
        assert!(proposal.status == STATUS_PASSED, EQuorumNotReached);

        let message_author = message::get_message_author(message);

        if (proposal.proposal_type == PROPOSAL_TYPE_HYPE) {
            // Update message status to HYPED
            message::update_message_status(message, 2); // STATUS_HYPED

            // Reward creator: +100 SWT
            token::transfer_from_treasury(treasury, HYPE_CREATOR_REWARD, message_author, ctx);

            // Reward each voting manager: +10 SWT
            let mut i = 0;
            while (i < vector::length(&proposal.voters)) {
                let voter = *vector::borrow(&proposal.voters, i);
                token::transfer_from_treasury(treasury, HYPE_MANAGER_REWARD, voter, ctx);
                i = i + 1;
            };

        } else if (proposal.proposal_type == PROPOSAL_TYPE_SCAM) {
            // Update message status to SPAM
            message::update_message_status(message, 3); // STATUS_SPAM

            // Creator penalty: -200 SWT (handled separately through slashing)
            // For now, just reward managers

            // Reward each voting manager: +10 SWT
            let mut i = 0;
            while (i < vector::length(&proposal.voters)) {
                let voter = *vector::borrow(&proposal.voters, i);
                token::transfer_from_treasury(treasury, SCAM_MANAGER_REWARD, voter, ctx);
                i = i + 1;
            };
        };

        proposal.status = STATUS_EXECUTED;
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
}

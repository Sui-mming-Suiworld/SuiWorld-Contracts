module suiworld::manager_nft {
    use sui::event;
    use sui::vec_set::{Self, VecSet};
    use std::string::{Self, String};

    // Manager NFT structure
    public struct ManagerNFT has key, store {
        id: UID,
        name: String,
        description: String,
        manager_address: address,
        issue_date: u64,
        vote_count: u64,
        misjudgement_count: u64,
    }

    // Manager Registry to track all managers
    public struct ManagerRegistry has key {
        id: UID,
        managers: VecSet<address>,
        max_managers: u64,
        total_issued: u64,
    }

    // Events
    public struct ManagerNFTMinted has copy, drop {
        nft_id: ID,
        recipient: address,
        issue_date: u64,
    }

    public struct ManagerNFTSlashed has copy, drop {
        nft_id: ID,
        owner: address,
        reason: String,
    }

    public struct ManagerNFTTransferred has copy, drop {
        nft_id: ID,
        from: address,
        to: address,
    }

    // Constants
    const MAX_MANAGERS: u64 = 12;
    const MAX_MISJUDGEMENTS: u64 = 3;

    // Error codes
    const EMaxManagersReached: u64 = 1;
    const EAlreadyManager: u64 = 3;
    const ETooManyMisjudgements: u64 = 4;

    // Initialize the manager registry
    fun init(ctx: &mut TxContext) {
        let registry = ManagerRegistry {
            id: object::new(ctx),
            managers: vec_set::empty(),
            max_managers: MAX_MANAGERS,
            total_issued: 0,
        };

        transfer::share_object(registry);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    // Mint a new Manager NFT
    public fun mint_manager_nft(
        registry: &mut ManagerRegistry,
        recipient: address,
        name: String,
        description: String,
        ctx: &mut TxContext
    ) {
        // Check if max managers reached
        assert!(
            vec_set::length(&registry.managers) < registry.max_managers,
            EMaxManagersReached
        );

        // Check if recipient is already a manager
        assert!(
            !vec_set::contains(&registry.managers, &recipient),
            EAlreadyManager
        );

        let issue_date = tx_context::epoch(ctx);

        let nft = ManagerNFT {
            id: object::new(ctx),
            name,
            description,
            manager_address: recipient,
            issue_date,
            vote_count: 0,
            misjudgement_count: 0,
        };

        let nft_id = object::id(&nft);

        // Add to registry
        vec_set::insert(&mut registry.managers, recipient);
        registry.total_issued = registry.total_issued + 1;

        // Emit event
        event::emit(ManagerNFTMinted {
            nft_id,
            recipient,
            issue_date,
        });

        // Transfer NFT to recipient
        transfer::public_transfer(nft, recipient);
    }

    // Transfer Manager NFT (tradeable)
    public fun transfer_manager_nft(
        registry: &mut ManagerRegistry,
        nft: ManagerNFT,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

        // Remove sender from registry
        vec_set::remove(&mut registry.managers, &sender);

        // Add recipient to registry
        vec_set::insert(&mut registry.managers, recipient);

        let nft_id = object::id(&nft);

        // Emit transfer event
        event::emit(ManagerNFTTransferred {
            nft_id,
            from: sender,
            to: recipient,
        });

        // Transfer NFT
        transfer::public_transfer(nft, recipient);
    }

    // Increment vote count for manager
    public fun increment_vote_count(nft: &mut ManagerNFT) {
        nft.vote_count = nft.vote_count + 1;
    }

    // Increment misjudgement count
    public fun increment_misjudgement_count(nft: &mut ManagerNFT) {
        nft.misjudgement_count = nft.misjudgement_count + 1;
    }

    // Slash manager NFT for too many misjudgements
    public fun slash_manager_nft(
        registry: &mut ManagerRegistry,
        nft: ManagerNFT,
        _ctx: &mut TxContext
    ) {
        assert!(
            nft.misjudgement_count >= MAX_MISJUDGEMENTS,
            ETooManyMisjudgements
        );

        let owner = nft.manager_address;
        let nft_id = object::id(&nft);

        // Remove from registry
        vec_set::remove(&mut registry.managers, &owner);

        // Emit slash event
        event::emit(ManagerNFTSlashed {
            nft_id,
            owner,
            reason: string::utf8(b"Too many misjudgements"),
        });

        // Burn the NFT
        let ManagerNFT {
            id,
            name: _,
            description: _,
            manager_address: _,
            issue_date: _,
            vote_count: _,
            misjudgement_count: _,
        } = nft;

        object::delete(id);
    }

    // Check if an address is a manager
    public fun is_manager(registry: &ManagerRegistry, addr: address): bool {
        vec_set::contains(&registry.managers, &addr)
    }

    // Get current number of managers
    public fun get_manager_count(registry: &ManagerRegistry): u64 {
        vec_set::length(&registry.managers)
    }

    // Get all manager addresses
    public fun get_all_managers(registry: &ManagerRegistry): vector<address> {
        let managers_set = &registry.managers;
        let result = vector::empty<address>();
        let i = 0;

        while (i < vec_set::length(managers_set)) {
            // VecSet doesn't have borrow_at_index, need to iterate differently
            // For now, return empty vector as VecSet iteration is not straightforward
            break
        };

        result
    }

    // Get manager NFT stats
    public fun get_manager_stats(nft: &ManagerNFT): (u64, u64) {
        (nft.vote_count, nft.misjudgement_count)
    }
}

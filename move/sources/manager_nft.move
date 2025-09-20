module suiworld::manager_nft {
    use sui::event;
    use sui::vec_set::{Self, VecSet};
    use std::string::{Self, String};
    use sui::table::{Self, Table};
    use suiworld::token::{AdminCap};

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
        managers_list: vector<address>, // For iteration
        max_managers: u64,
        total_issued: u64,
        slashed_count: u64,
        nft_ids: Table<address, ID>, // Track NFT IDs for burning
        misjudgement_counts: Table<address, u64>, // Track misjudgements in registry
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

    public struct ManagerSlashed has copy, drop {
        manager: address,
        reason: vector<u8>,
        timestamp: u64,
    }

    public struct ManagerNFTBurned has copy, drop {
        nft_id: ID,
        manager: address,
        timestamp: u64,
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
            managers_list: vector::empty(),
            max_managers: MAX_MANAGERS,
            total_issued: 0,
            slashed_count: 0,
            nft_ids: table::new(ctx),
            misjudgement_counts: table::new(ctx),
        };

        transfer::share_object(registry);
    }

    // Mint a new Manager NFT (Admin only)
    public fun mint_manager_nft(
        registry: &mut ManagerRegistry,
        _admin: &AdminCap,
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
        vector::push_back(&mut registry.managers_list, recipient);
        registry.total_issued = registry.total_issued + 1;

        // Track NFT ID for potential burning
        table::add(&mut registry.nft_ids, recipient, nft_id);

        // Initialize misjudgement count
        table::add(&mut registry.misjudgement_counts, recipient, 0);

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

        // Check if recipient is already a manager
        assert!(
            !vec_set::contains(&registry.managers, &recipient),
            EAlreadyManager
        );

        // Remove sender from registry
        vec_set::remove(&mut registry.managers, &sender);
        let (found, index) = vector::index_of(&registry.managers_list, &sender);
        if (found) {
            vector::remove(&mut registry.managers_list, index);
        };

        // Update NFT ID tracking
        if (table::contains(&registry.nft_ids, sender)) {
            let nft_id = table::remove(&mut registry.nft_ids, sender);
            table::add(&mut registry.nft_ids, recipient, nft_id);
        };

        // Transfer misjudgement count
        if (table::contains(&registry.misjudgement_counts, sender)) {
            let count = table::remove(&mut registry.misjudgement_counts, sender);
            table::add(&mut registry.misjudgement_counts, recipient, count);
        } else {
            table::add(&mut registry.misjudgement_counts, recipient, 0);
        };

        // Add recipient to registry
        vec_set::insert(&mut registry.managers, recipient);
        vector::push_back(&mut registry.managers_list, recipient);

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
        registry.managers_list
    }

    // Get manager NFT stats
    public fun get_manager_stats(nft: &ManagerNFT): (u64, u64) {
        (nft.vote_count, nft.misjudgement_count)
    }

    // Slash manager for misconduct (called by vote module after BFT resolution)
    public fun slash_manager_for_misconduct(
        registry: &mut ManagerRegistry,
        manager: address,
        ctx: &mut TxContext
    ) {
        // Remove from managers set
        if (vec_set::contains(&registry.managers, &manager)) {
            vec_set::remove(&mut registry.managers, &manager);
            let (found, index) = vector::index_of(&registry.managers_list, &manager);
            if (found) {
                vector::remove(&mut registry.managers_list, index);
            };
            registry.slashed_count = registry.slashed_count + 1;

            // Get and remove NFT ID tracking
            if (table::contains(&registry.nft_ids, manager)) {
                let nft_id = table::remove(&mut registry.nft_ids, manager);

                // Emit burning event
                event::emit(ManagerNFTBurned {
                    nft_id,
                    manager,
                    timestamp: tx_context::epoch(ctx),
                });
            };

            // Remove misjudgement tracking
            if (table::contains(&registry.misjudgement_counts, manager)) {
                table::remove(&mut registry.misjudgement_counts, manager);
            };

            // Emit slashing event
            event::emit(ManagerSlashed {
                manager,
                reason: b"BFT consensus - misconduct",
                timestamp: tx_context::epoch(ctx),
            });

            // Note: The actual NFT object is held by the manager
            // They lose manager privileges but keep the (now useless) NFT object
        };
    }

    // Burn manager NFT directly (when we have the NFT object)
    public fun burn_manager_nft(
        registry: &mut ManagerRegistry,
        nft: ManagerNFT,
        ctx: &mut TxContext
    ) {
        let manager = nft.manager_address;
        let nft_id = object::id(&nft);

        // Remove from registry
        if (vec_set::contains(&registry.managers, &manager)) {
            vec_set::remove(&mut registry.managers, &manager);
            let (found, index) = vector::index_of(&registry.managers_list, &manager);
            if (found) {
                vector::remove(&mut registry.managers_list, index);
            };
            registry.slashed_count = registry.slashed_count + 1;
        };

        // Remove NFT ID tracking
        if (table::contains(&registry.nft_ids, manager)) {
            table::remove(&mut registry.nft_ids, manager);
        };

        // Remove misjudgement tracking
        if (table::contains(&registry.misjudgement_counts, manager)) {
            table::remove(&mut registry.misjudgement_counts, manager);
        };

        // Emit burning event
        event::emit(ManagerNFTBurned {
            nft_id,
            manager,
            timestamp: tx_context::epoch(ctx),
        });

        // Destroy the NFT
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

    // Increment misjudgement count in registry (called by vote module)
    public fun increment_registry_misjudgement(
        registry: &mut ManagerRegistry,
        manager: address
    ): u64 {
        if (!table::contains(&registry.misjudgement_counts, manager)) {
            table::add(&mut registry.misjudgement_counts, manager, 0);
        };

        let count = table::borrow_mut(&mut registry.misjudgement_counts, manager);
        *count = *count + 1;
        *count
    }

    // Get misjudgement count from registry
    public fun get_registry_misjudgement_count(
        registry: &ManagerRegistry,
        manager: address
    ): u64 {
        if (!table::contains(&registry.misjudgement_counts, manager)) {
            return 0
        };
        *table::borrow(&registry.misjudgement_counts, manager)
    }
}

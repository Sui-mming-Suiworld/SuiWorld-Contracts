module suiworld::message {
    use sui::table::{Self, Table};
    use sui::event;
    use std::string::String;
    use suiworld::token::{Self, TOKEN as SWT};
    use suiworld::manager_nft::{Self, ManagerRegistry};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};

    // Message status constants (exported for other modules)
    public fun status_normal(): u8 { 0 }
    public fun status_under_review(): u8 { 1 }
    public fun status_hyped(): u8 { 2 }
    public fun status_spam(): u8 { 3 }
    public fun status_deleted(): u8 { 4 }

    // Internal constants
    const STATUS_NORMAL: u8 = 0;
    const STATUS_UNDER_REVIEW: u8 = 1;
    const STATUS_HYPED: u8 = 2;
    const STATUS_SPAM: u8 = 3;
    const STATUS_DELETED: u8 = 4;

    // Message structure
    public struct Message has key, store {
        id: UID,
        author: address,
        title_hash: vector<u8>,  // Hash of the title
        content_hash: vector<u8>, // Hash of the content
        tags: vector<String>,
        status: u8,
        likes: u64,
        alerts: u64,
        created_at: u64,
        updated_at: u64,
    }

    // Comment structure
    public struct Comment has key, store {
        id: UID,
        message_id: ID,
        author: address,
        content_hash: vector<u8>, // Hash of the comment content
        likes: u64,
        created_at: u64,
    }

    // Message Board to track all messages
    public struct MessageBoard has key {
        id: UID,
        messages: Table<ID, bool>,
        total_messages: u64,
        total_comments: u64,
    }

    // User interactions tracking
    public struct UserInteractions has key {
        id: UID,
        user_likes: Table<address, vector<ID>>,
        user_alerts: Table<address, vector<ID>>,
        message_likers: Table<ID, vector<address>>,
        message_alerters: Table<ID, vector<address>>,
    }

    // Lockup vault for staked SWT tokens
    public struct LockupVault has key {
        id: UID,
        locked_tokens: Table<address, Balance<SWT>>,  // User -> locked balance
        lockup_expiry: Table<address, u64>,  // User -> lockup expiry epoch
        message_stakes: Table<ID, address>,  // Message ID -> author who staked
        total_locked: u64,
    }

    // Events
    public struct MessageCreated has copy, drop {
        message_id: ID,
        author: address,
        title_hash: vector<u8>,
        created_at: u64,
    }

    public struct MessageUpdated has copy, drop {
        message_id: ID,
        status: u8,
        updated_at: u64,
    }

    public struct MessageDeleted has copy, drop {
        message_id: ID,
        deleted_by: address,
    }

    public struct CommentCreated has copy, drop {
        comment_id: ID,
        message_id: ID,
        author: address,
    }

    public struct MessageLiked has copy, drop {
        message_id: ID,
        user: address,
        total_likes: u64,
    }

    public struct MessageAlerted has copy, drop {
        message_id: ID,
        user: address,
        total_alerts: u64,
    }

    // Constants
    const LOCKUP_FOR_MESSAGE: u64 = 1000_000_000; // 1000 SWT lockup for message
    const MIN_SWT_FOR_UPDATE: u64 = 1000_000_000;
    const MIN_SWT_FOR_COMMENT: u64 = 100_000_000; // 100 SWT for comment
    const REVIEW_THRESHOLD_LIKES: u64 = 20;
    const REVIEW_THRESHOLD_ALERTS: u64 = 20;
    const LOCKUP_DURATION_EPOCHS: u64 = 168; // ~1 week (1 epoch = 1 hour on Sui)
    const SCAM_PENALTY_AMOUNT: u64 = 500_000_000; // 500 SWT penalty for SCAM

    // Error codes
    const EInsufficientSWT: u64 = 1;
    const ENotAuthorized: u64 = 2;
    const EAlreadyLiked: u64 = 3;
    const EAlreadyAlerted: u64 = 4;
    const EInvalidStatus: u64 = 5;
    const EAlreadyHasLockedTokens: u64 = 6;
    const ENoLockedTokens: u64 = 7;
    const EMessageNotOwnedByCaller: u64 = 8;
    const ELockupNotExpired: u64 = 9;

    // Initialize message board
    fun init(ctx: &mut TxContext) {
        let message_board = MessageBoard {
            id: object::new(ctx),
            messages: table::new(ctx),
            total_messages: 0,
            total_comments: 0,
        };

        let interactions = UserInteractions {
            id: object::new(ctx),
            user_likes: table::new(ctx),
            user_alerts: table::new(ctx),
            message_likers: table::new(ctx),
            message_alerters: table::new(ctx),
        };

        let lockup_vault = LockupVault {
            id: object::new(ctx),
            locked_tokens: table::new(ctx),
            lockup_expiry: table::new(ctx),
            message_stakes: table::new(ctx),
            total_locked: 0,
        };

        transfer::share_object(message_board);
        transfer::share_object(interactions);
        transfer::share_object(lockup_vault);
    }

    // Create a new message with SWT lockup
    public fun create_message(
        board: &mut MessageBoard,
        vault: &mut LockupVault,
        mut swt_coin: Coin<SWT>,
        title_hash: vector<u8>,
        content_hash: vector<u8>,
        tags: vector<String>,
        ctx: &mut TxContext
    ) {
        let author = tx_context::sender(ctx);
        let current_epoch = tx_context::epoch(ctx);

        // Check if user already has locked tokens
        if (table::contains(&vault.locked_tokens, author)) {
            // User already has locked tokens, just extend the lockup period
            let expiry = table::borrow_mut(&mut vault.lockup_expiry, author);
            *expiry = current_epoch + LOCKUP_DURATION_EPOCHS; // Reset to 1 week from now

            // Return the coins since we don't need more lockup
            transfer::public_transfer(swt_coin, author);
        } else {
            // New lockup required
            // Check SWT balance requirement
            assert!(
                coin::value(&swt_coin) >= LOCKUP_FOR_MESSAGE,
                EInsufficientSWT
            );

            // Lock exactly 1000 SWT
            let lockup_coin = coin::split(&mut swt_coin, LOCKUP_FOR_MESSAGE, ctx);
            let lockup_balance = coin::into_balance(lockup_coin);

            // Return remaining coins to sender if any
            if (coin::value(&swt_coin) > 0) {
                transfer::public_transfer(swt_coin, author);
            } else {
                coin::destroy_zero(swt_coin);
            };

            // Store locked tokens in vault with expiry
            table::add(&mut vault.locked_tokens, author, lockup_balance);
            table::add(&mut vault.lockup_expiry, author, current_epoch + LOCKUP_DURATION_EPOCHS);
            vault.total_locked = vault.total_locked + LOCKUP_FOR_MESSAGE;
        };

        let created_at = tx_context::epoch(ctx);

        let message = Message {
            id: object::new(ctx),
            author,
            title_hash,
            content_hash,
            tags,
            status: STATUS_NORMAL,
            likes: 0,
            alerts: 0,
            created_at,
            updated_at: created_at,
        };

        let message_id = object::id(&message);

        // Link message to staker
        table::add(&mut vault.message_stakes, message_id, author);

        // Add to board
        table::add(&mut board.messages, message_id, true);
        board.total_messages = board.total_messages + 1;

        // Emit event
        event::emit(MessageCreated {
            message_id,
            author,
            title_hash: message.title_hash,
            created_at,
        });

        // Share the message object
        transfer::share_object(message);
    }

    // Update message (requires SWT or Manager NFT)
    public fun update_message(
        message: &mut Message,
        swt_coin: &Coin<SWT>,
        manager_registry: &ManagerRegistry,
        new_content_hash: vector<u8>,
        new_tags: vector<String>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

        // Check authorization: either have enough SWT or be a manager
        let has_swt = token::check_minimum_balance(swt_coin, MIN_SWT_FOR_UPDATE);
        let is_manager = manager_nft::is_manager(manager_registry, sender);

        assert!(has_swt || is_manager, ENotAuthorized);

        message.content_hash = new_content_hash;
        message.tags = new_tags;
        message.updated_at = tx_context::epoch(ctx);

        event::emit(MessageUpdated {
            message_id: object::id(message),
            status: message.status,
            updated_at: message.updated_at,
        });
    }

    // Delete message (Manager only)
    public fun delete_message(
        message: &mut Message,
        manager_registry: &ManagerRegistry,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

        // Only managers can delete
        assert!(manager_nft::is_manager(manager_registry, sender), ENotAuthorized);

        message.status = STATUS_DELETED;

        event::emit(MessageDeleted {
            message_id: object::id(message),
            deleted_by: sender,
        });
    }

    // Like a message
    public fun like_message(
        message: &mut Message,
        interactions: &mut UserInteractions,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        let message_id = object::id(message);

        // Check if already liked
        if (!table::contains(&interactions.user_likes, user)) {
            table::add(&mut interactions.user_likes, user, vector::empty());
        };

        let user_liked_messages = table::borrow_mut(&mut interactions.user_likes, user);

        // Check if message already liked by user
        let mut already_liked = false;
        let mut i = 0;
        while (i < vector::length(user_liked_messages)) {
            if (*vector::borrow(user_liked_messages, i) == message_id) {
                already_liked = true;
                break
            };
            i = i + 1;
        };

        assert!(!already_liked, EAlreadyLiked);

        // Add like
        vector::push_back(user_liked_messages, message_id);
        message.likes = message.likes + 1;

        // Track liker for the message
        if (!table::contains(&interactions.message_likers, message_id)) {
            table::add(&mut interactions.message_likers, message_id, vector::empty());
        };
        let likers = table::borrow_mut(&mut interactions.message_likers, message_id);
        vector::push_back(likers, user);

        // Check if should go under review
        if (message.likes >= REVIEW_THRESHOLD_LIKES && message.status == STATUS_NORMAL) {
            message.status = STATUS_UNDER_REVIEW;
        };

        event::emit(MessageLiked {
            message_id,
            user,
            total_likes: message.likes,
        });
    }

    // Alert (report) a message
    public fun alert_message(
        message: &mut Message,
        interactions: &mut UserInteractions,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        let message_id = object::id(message);

        // Check if already alerted
        if (!table::contains(&interactions.user_alerts, user)) {
            table::add(&mut interactions.user_alerts, user, vector::empty());
        };

        let user_alerted_messages = table::borrow_mut(&mut interactions.user_alerts, user);

        // Check if message already alerted by user
        let mut already_alerted = false;
        let mut i = 0;
        while (i < vector::length(user_alerted_messages)) {
            if (*vector::borrow(user_alerted_messages, i) == message_id) {
                already_alerted = true;
                break
            };
            i = i + 1;
        };

        assert!(!already_alerted, EAlreadyAlerted);

        // Add alert
        vector::push_back(user_alerted_messages, message_id);
        message.alerts = message.alerts + 1;

        // Track alerter for the message
        if (!table::contains(&interactions.message_alerters, message_id)) {
            table::add(&mut interactions.message_alerters, message_id, vector::empty());
        };
        let alerters = table::borrow_mut(&mut interactions.message_alerters, message_id);
        vector::push_back(alerters, user);

        // Check if should go under review
        if (message.alerts >= REVIEW_THRESHOLD_ALERTS && message.status == STATUS_NORMAL) {
            message.status = STATUS_UNDER_REVIEW;
        };

        event::emit(MessageAlerted {
            message_id,
            user,
            total_alerts: message.alerts,
        });
    }

    // Create a comment
    public fun create_comment(
        board: &mut MessageBoard,
        swt_coin: &Coin<SWT>,
        message_id: ID,
        content_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        // Check SWT balance requirement
        assert!(
            coin::value(swt_coin) >= MIN_SWT_FOR_COMMENT,
            EInsufficientSWT
        );

        let author = tx_context::sender(ctx);
        let created_at = tx_context::epoch(ctx);

        let comment = Comment {
            id: object::new(ctx),
            message_id,
            author,
            content_hash,
            likes: 0,
            created_at,
        };

        let comment_id = object::id(&comment);

        board.total_comments = board.total_comments + 1;

        event::emit(CommentCreated {
            comment_id,
            message_id,
            author,
        });

        transfer::share_object(comment);
    }

    // Unlock tokens after lockup period expires
    public fun unlock_tokens(
        vault: &mut LockupVault,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_epoch = tx_context::epoch(ctx);

        // Check if user has locked tokens
        assert!(
            table::contains(&vault.locked_tokens, sender),
            ENoLockedTokens
        );

        // Check if lockup period has expired
        let expiry = *table::borrow(&vault.lockup_expiry, sender);
        assert!(
            current_epoch >= expiry,
            ELockupNotExpired
        );

        // Remove and get the locked balance
        let locked_balance = table::remove(&mut vault.locked_tokens, sender);
        let unlock_amount = balance::value(&locked_balance);

        // Remove expiry entry
        table::remove(&mut vault.lockup_expiry, sender);

        // Convert balance back to coin and transfer to user
        let unlocked_coin = coin::from_balance(locked_balance, ctx);
        transfer::public_transfer(unlocked_coin, sender);

        // Update total locked
        vault.total_locked = vault.total_locked - unlock_amount;

        // Note: User can't create new messages after unlocking until they lock again
    }

    // Manager function to slash spam messages and take locked tokens
    public fun slash_message(
        message: &mut Message,
        vault: &mut LockupVault,
        registry: &ManagerRegistry,
        treasury: &mut suiworld::token::Treasury,
        message_id: ID,
        ctx: &mut TxContext
    ) {
        let manager = tx_context::sender(ctx);

        // Check if caller is a manager
        assert!(
            manager_nft::is_manager(registry, manager),
            ENotAuthorized
        );

        // Check if message has staked tokens
        assert!(
            table::contains(&vault.message_stakes, message_id),
            ENoLockedTokens
        );

        // Get the author who staked for this message
        let author = table::remove(&mut vault.message_stakes, message_id);

        // Remove and slash the locked tokens
        if (table::contains(&vault.locked_tokens, author)) {
            let mut locked_balance = table::remove(&mut vault.locked_tokens, author);
            let total_locked = balance::value(&locked_balance);

            // Calculate penalty: 500 SWT or all if less than 500
            let penalty_amount = if (total_locked >= SCAM_PENALTY_AMOUNT) {
                SCAM_PENALTY_AMOUNT
            } else {
                total_locked
            };

            // Split the penalty amount
            let penalty_balance = balance::split(&mut locked_balance, penalty_amount);

            // If there's remaining balance, return it to the author
            if (balance::value(&locked_balance) > 0) {
                // Keep the remaining locked tokens in the vault
                table::add(&mut vault.locked_tokens, author, locked_balance);
                // Update expiry - keep the same expiry time
                // (expiry entry is not removed in this case)
            } else {
                // No remaining balance, remove expiry
                table::remove(&mut vault.lockup_expiry, author);
                balance::destroy_zero(locked_balance);
            };

            // Return penalty tokens to treasury for redistribution
            token::return_tokens_to_treasury(treasury, penalty_balance);

            // Update total locked
            vault.total_locked = vault.total_locked - penalty_amount;

            // Mark message as deleted
            message.status = STATUS_DELETED;
            message.updated_at = tx_context::epoch(ctx);

            // Emit slashing event
            event::emit(MessageDeleted {
                message_id,
                deleted_by: manager,
            });
        };
    }

    // Update message status (called by vote module)
    public fun update_message_status(message: &mut Message, new_status: u8) {
        assert!(new_status <= STATUS_DELETED, EInvalidStatus);
        message.status = new_status;
    }

    // Getter functions
    public fun get_message_status(message: &Message): u8 {
        message.status
    }

    public fun get_message_likes(message: &Message): u64 {
        message.likes
    }

    public fun get_message_alerts(message: &Message): u64 {
        message.alerts
    }

    public fun get_message_author(message: &Message): address {
        message.author
    }

    public fun get_message_title_hash(message: &Message): vector<u8> {
        message.title_hash
    }

    public fun get_message_content_hash(message: &Message): vector<u8> {
        message.content_hash
    }

    public fun is_under_review(message: &Message): bool {
        message.status == STATUS_UNDER_REVIEW
    }

    public fun has_locked_tokens(vault: &LockupVault, user: address): bool {
        table::contains(&vault.locked_tokens, user)
    }

    public fun get_total_locked(vault: &LockupVault): u64 {
        vault.total_locked
    }

    // Get user's locked balance
    public fun get_locked_balance(vault: &LockupVault, user: address): u64 {
        if (!table::contains(&vault.locked_tokens, user)) {
            return 0
        };
        balance::value(table::borrow(&vault.locked_tokens, user))
    }
}

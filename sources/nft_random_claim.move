module nft_collection::random_nft {
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::randomness;

    // Error codes
    const NFT_ALREADY_EXISTS: u64 = 1;
    const NFT_DOES_NOT_EXIST: u64 = 2;
    const NOT_OWNER: u64 = 3;
    const COLLECTION_NOT_INITIALIZED: u64 = 4;
    const ALL_TOKENS_CLAIMED: u64 = 5;

    // Struct to store NFT data
    struct NFT has store, drop {
        name: String,
        description: String,
        uri: String,
    }

    // Collection data stored in global storage
    struct Collection has key {
        nfts: SimpleMap<u64, NFT>,
        total_supply: u64,
        minted: u64,
        mint_events: EventHandle<MintEvent>,
    }

    // Event emitted when an NFT is minted
    struct MintEvent has drop, store {
        token_id: u64,
        recipient: address,
        timestamp: u64,
    }

    // Initialize module with resource account
    fun init_module(account: &signer) {
        let collection = Collection {
            nfts: simple_map::create(),
            total_supply: 100, // Example total supply
            minted: 0,
            mint_events: account::new_event_handle<MintEvent>(account),
        };
        move_to(account, collection);
    }

    // Add NFT to collection (admin only)
    public entry fun add_nft(
        admin: &signer,
        token_id: u64,
        name: String,
        description: String,
        uri: String
    ) acquires Collection {
        let admin_addr = signer::address_of(admin);
        assert!(exists<Collection>(admin_addr), error::not_found(COLLECTION_NOT_INITIALIZED));
        
        let collection = borrow_global_mut<Collection>(admin_addr);
        assert!(!simple_map::contains_key(&collection.nfts, &token_id), error::already_exists(NFT_ALREADY_EXISTS));

        let nft = NFT {
            name,
            description,
            uri,
        };
        simple_map::add(&mut collection.nfts, token_id, nft);
    }

    // Claim a random NFT
    #[lint::allow_unsafe_randomness]
    public entry fun claim_random_nft(recipient: &signer) acquires Collection {
        let recipient_addr = signer::address_of(recipient);
        let collection = borrow_global_mut<Collection>(@nft_collection);
        
        assert!(collection.minted < collection.total_supply, error::invalid_state(ALL_TOKENS_CLAIMED));

        // Get random number using Aptos randomness
        let random_seed = randomness::u64_range(0, collection.total_supply);
        
        // Find next available token
        let token_id = find_next_available_token(collection, random_seed);
        
        // Emit mint event
        event::emit_event(&mut collection.mint_events, MintEvent {
            token_id,
            recipient: recipient_addr,
            timestamp: timestamp::now_seconds(),
        });

        collection.minted = collection.minted + 1;
    }

    // Helper function to find next available token
    fun find_next_available_token(collection: &Collection, start_index: u64): u64 {
        let current_index = start_index;
        while (current_index < collection.total_supply) {
            if (simple_map::contains_key(&collection.nfts, &current_index)) {
                return current_index
            };
            current_index = current_index + 1;
        };
        
        // If we didn't find a token after start_index, look from beginning
        current_index = 0;
        while (current_index < start_index) {
            if (simple_map::contains_key(&collection.nfts, &current_index)) {
                return current_index
            };
            current_index = current_index + 1;
        };
        abort error::invalid_state(ALL_TOKENS_CLAIMED)
    }

    // Getter functions
    #[view]
    public fun get_nft_info(token_id: u64): (String, String, String) acquires Collection {
        let collection = borrow_global<Collection>(@nft_collection);
        assert!(simple_map::contains_key(&collection.nfts, &token_id), error::not_found(NFT_DOES_NOT_EXIST));
        
        let nft = simple_map::borrow(&collection.nfts, &token_id);
        (nft.name, nft.description, nft.uri)
    }

    #[view]
    public fun get_total_supply(): u64 acquires Collection {
        let collection = borrow_global<Collection>(@nft_collection);
        collection.total_supply
    }

    #[view]
    public fun get_minted(): u64 acquires Collection {
        let collection = borrow_global<Collection>(@nft_collection);
        collection.minted
    }

    #[test_only]
    public fun initialize_for_test(account: &signer) {
        init_module(account)
    }
}
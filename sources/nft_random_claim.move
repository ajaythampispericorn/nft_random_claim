module nft_collection::random_nft {
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::randomness;
    use aptos_framework::resource_account;

    // Define module addresses
    const ADMIN_ADDRESS: address = @nft_collection;

    const ENFT_ALREADY_EXISTS: u64 = 0x50001;
    const ENOT_OWNER: u64 = 0x30001;
    const ENFT_DOES_NOT_EXIST: u64 = 0x40001;
    const ECOLLECTION_NOT_INITIALIZED: u64 = 0x40002;
    const EALL_TOKENS_CLAIMED: u64 = 0x60001;

    // Store signer capability for the resource account
    struct ResourceAccountCap has key {
        signer_cap: SignerCapability
    }

    // Struct to store NFT data
    struct NFT has store, drop {
        name: String,
        description: String,
        uri: String,
    }

    // Collection data stored in resource account storage
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

    // Initialize module and create resource account
    fun init_module(admin: &signer) {
        // Create resource account from module address
        let (resource_signer, signer_cap) = account::create_resource_account(admin, vector::empty());
        
        // Store signer capability
        move_to(admin, ResourceAccountCap {
            signer_cap
        });

        // Initialize collection in resource account storage
        let collection = Collection {
            nfts: simple_map::new(),
            total_supply: 100,
            minted: 0,
            mint_events: account::new_event_handle<MintEvent>(&resource_signer),
        };
        move_to(&resource_signer, collection);
    }

    // Add NFT to collection (admin only)
    public entry fun add_nft(
        admin: &signer,
        token_id: u64,
        name: String,
        description: String,
        uri: String
    ) acquires Collection, ResourceAccountCap {
        assert!(signer::address_of(admin) == ADMIN_ADDRESS, error::permission_denied(ENOT_OWNER));
        
        // Get resource account address from capability
        let resource_cap = borrow_global<ResourceAccountCap>(ADMIN_ADDRESS);
        let resource_account_address = account::get_signer_capability_address(&resource_cap.signer_cap);
        
        assert!(exists<Collection>(resource_account_address), error::not_found(ECOLLECTION_NOT_INITIALIZED));
        
        let collection = borrow_global_mut<Collection>(resource_account_address);
        assert!(!simple_map::contains_key(&collection.nfts, &token_id), error::already_exists(ENFT_ALREADY_EXISTS));

        let nft = NFT {
            name,
            description,
            uri,
        };
        simple_map::add(&mut collection.nfts, token_id, nft);
    }

    // Claim a random NFT
    #[lint::allow_unsafe_randomness]
    public entry fun claim_random_nft(recipient: &signer) acquires Collection, ResourceAccountCap {
        let recipient_addr = signer::address_of(recipient);
        
        // Get resource account address from capability
        let resource_cap = borrow_global<ResourceAccountCap>(ADMIN_ADDRESS);
        let resource_account_address = account::get_signer_capability_address(&resource_cap.signer_cap);
        
        let collection = borrow_global_mut<Collection>(resource_account_address);
        assert!(collection.minted < collection.total_supply, error::invalid_state(EALL_TOKENS_CLAIMED));

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
        if (!simple_map::contains_key(&collection.nfts, &current_index)) {
            return current_index
        };
        current_index = current_index + 1;
    };
    
    // If we didn't find a token after start_index, look from beginning
    current_index = 0;
    while (current_index < start_index) {
        if (!simple_map::contains_key(&collection.nfts, &current_index)) {
            return current_index
        };
        current_index = current_index + 1;
    };
    abort error::invalid_state(EALL_TOKENS_CLAIMED)
    }

    // Getter functions
    #[view]
    public fun get_nft_info(token_id: u64): (String, String, String) acquires Collection, ResourceAccountCap {
        let resource_cap = borrow_global<ResourceAccountCap>(ADMIN_ADDRESS);
        let resource_account_address = account::get_signer_capability_address(&resource_cap.signer_cap);
        
        let collection = borrow_global<Collection>(resource_account_address);
        assert!(simple_map::contains_key(&collection.nfts, &token_id), error::not_found(ENFT_DOES_NOT_EXIST));
        
        let nft = simple_map::borrow(&collection.nfts, &token_id);
        (nft.name, nft.description, nft.uri)
    }

    #[view]
    public fun get_total_supply(): u64 acquires Collection, ResourceAccountCap {
        let resource_cap = borrow_global<ResourceAccountCap>(ADMIN_ADDRESS);
        let resource_account_address = account::get_signer_capability_address(&resource_cap.signer_cap);
        
        let collection = borrow_global<Collection>(resource_account_address);
        collection.total_supply
    }

    #[view]
    public fun get_minted(): u64 acquires Collection, ResourceAccountCap {
        let resource_cap = borrow_global<ResourceAccountCap>(ADMIN_ADDRESS);
        let resource_account_address = account::get_signer_capability_address(&resource_cap.signer_cap);
        
        let collection = borrow_global<Collection>(resource_account_address);
        collection.minted
    }

    #[test_only]
    public fun initialize_for_test(admin: &signer) {
        init_module(admin)
    }

    #[test_only]
    public fun test_has_resource_cap(addr: address): bool {
        exists<ResourceAccountCap>(addr)
    }

    #[test_only]
    public fun test_get_resource_account_address(admin_addr: address): address acquires ResourceAccountCap {
        let resource_cap = borrow_global<ResourceAccountCap>(admin_addr);
        account::get_signer_capability_address(&resource_cap.signer_cap)
    }

    #[test_only]
    public fun test_has_collection(addr: address): bool {
        exists<Collection>(addr)
    }

    #[test_only]
    public fun initialize_resource_cap_for_test(admin: &signer) {
        let (_, signer_cap) = account::create_resource_account(admin, vector::empty());
        move_to(admin, ResourceAccountCap {
            signer_cap
        });
    }
}
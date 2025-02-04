// module nft_collection::random_nft {
//     use std::string::{String, utf8};
//     use std::vector;
//     use std::signer;
//     use aptos_framework::account;
//     use aptos_framework::resource_account;
//     use aptos_framework::randomness;
//     use aptos_token::token;
//     use aptos_std::simple_map::{Self, SimpleMap};

//     const ESOLD_OUT: u64 = 2;
//     const EPAUSED: u64 = 3;
//     const EINVALID_RESOURCE_ADDRESS: u64 = 4;

//     struct CollectionState has key {
//         signer_cap: account::SignerCapability,
//         available_tokens: SimpleMap<u64, TokenMetadata>,
//         total_supply: u64,
//         claimed_tokens: u64,
//         paused: bool,
//         contract_address: address,
//     }

//     struct TokenMetadata has store, drop {
//         name: String,
//         description: String,
//         uri: String,
//     }

//     public entry fun initialize(
//         admin: &signer,
//         resource_addr: address,
//         collection_name: String,
//         description: String,
//         uri: String,
//         total_supply: u64,
//     ) {
//         assert!(resource_addr == @nft_collection, EINVALID_RESOURCE_ADDRESS);
        
//         let signer_cap = resource_account::retrieve_resource_account_cap(admin, resource_addr);
//         let resource_signer = account::create_signer_with_capability(&signer_cap);

//         token::create_collection(
//             &resource_signer,
//             collection_name,
//             description,
//             uri,
//             total_supply,
//             vector<bool>[true, true, true],
//         );

//         let available_tokens = simple_map::create();
//         move_to(&resource_signer, CollectionState {
//             signer_cap,
//             available_tokens,
//             total_supply,
//             claimed_tokens: 0,
//             paused: false,
//             contract_address: @nft_collection,
//         });
//     }

//     public entry fun add_token(
//         admin: &signer,
//         token_id: u64,
//         name: String,
//         description: String,
//         uri: String,
//     ) acquires CollectionState {
//         let state = borrow_global_mut<CollectionState>(signer::address_of(admin));
//         assert!(signer::address_of(admin) == @nft_collection, EINVALID_RESOURCE_ADDRESS);

//         simple_map::add(&mut state.available_tokens, token_id, TokenMetadata {
//             name,
//             description,
//             uri,
//         });
//     }

//     #[randomness]
//     entry fun claim_nft(
//         claimer: &signer,
//         resource_addr: address,
//         collection_name: String,
//     ) acquires CollectionState {
//         let state = borrow_global_mut<CollectionState>(resource_addr);
//         assert!(state.contract_address == @nft_collection, EINVALID_RESOURCE_ADDRESS);
//         assert!(!state.paused, EPAUSED);
//         assert!(state.claimed_tokens < state.total_supply, ESOLD_OUT);

//         let rand_num = randomness::u64_range(0, state.total_supply);
//         let token_id = find_available_token(rand_num, state);
//         let (_, metadata) = simple_map::remove(&mut state.available_tokens, &token_id);

//         let resource_signer = account::create_signer_with_capability(&state.signer_cap);
//         token::create_token_script(
//             &resource_signer,
//             collection_name,
//             metadata.name,
//             metadata.description,
//             1,  // token amount
//             0,  // maximum amount
//             metadata.uri, // token uri
//             signer::address_of(claimer),  // royalty payee address
//             0,  // royalty points denominator
//             0,  // royalty points numerator
//             vector<bool>[false, false, false, false, false],  // collection mutate setting
//             vector::empty<String>(),  // property keys
//             vector::empty<vector<u8>>(),  // property values
//             vector::empty<String>(),  // property types
//         );

//         state.claimed_tokens = state.claimed_tokens + 1;
//     }

//     fun find_available_token(rand_num: u64, state: &CollectionState): u64 {
//         let i = 0;
        
//         while (i < state.total_supply) {
//             if (simple_map::contains_key(&state.available_tokens, &i)) {
//                 if (rand_num == 0) {
//                     return i
//                 };
//                 rand_num = rand_num - 1;
//             };
//             i = i + 1;
//         };
//         abort 999
//     }

//     public entry fun pause(admin: &signer, resource_addr: address) acquires CollectionState {
//         let state = borrow_global_mut<CollectionState>(resource_addr);
//         assert!(state.contract_address == @nft_collection, EINVALID_RESOURCE_ADDRESS);
//         assert!(signer::address_of(admin) == account::get_signer_capability_address(&state.signer_cap), 0);
//         state.paused = true;
//     }

//     public entry fun unpause(admin: &signer, resource_addr: address) acquires CollectionState {
//         let state = borrow_global_mut<CollectionState>(resource_addr);
//         assert!(state.contract_address == @nft_collection, EINVALID_RESOURCE_ADDRESS);
//         assert!(signer::address_of(admin) == account::get_signer_capability_address(&state.signer_cap), 0);
//         state.paused = false;
//     }
// }

module nft_collection::random_nft {
    use std::string::{String, utf8};
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use aptos_framework::randomness;
    use aptos_token::token;
    use aptos_std::simple_map::{Self, SimpleMap};

    const ESOLD_OUT: u64 = 2;
    const EPAUSED: u64 = 3;
    const EINVALID_RESOURCE_ADDRESS: u64 = 4;

    struct CollectionState has key {
        signer_cap: account::SignerCapability,
        available_tokens: SimpleMap<u64, TokenMetadata>,
        total_supply: u64,
        claimed_tokens: u64,
        paused: bool,
        contract_address: address,
    }

    struct TokenMetadata has store, drop {
        name: String,
        description: String,
        uri: String,
    }

    public entry fun initialize(
        admin: &signer,
        resource_addr: address,
        collection_name: String,
        description: String,
        uri: String,
        total_supply: u64,
    ) {
        initialize_internal(admin, resource_addr, collection_name, description, uri, total_supply);
    }

    public fun initialize_internal(
        admin: &signer,
        resource_addr: address,
        collection_name: String,
        description: String,
        uri: String,
        total_supply: u64,
    ) {
        assert!(resource_addr == @nft_collection, EINVALID_RESOURCE_ADDRESS);
        
        let signer_cap = resource_account::retrieve_resource_account_cap(admin, resource_addr);
        let resource_signer = account::create_signer_with_capability(&signer_cap);

        token::create_collection(
            &resource_signer,
            collection_name,
            description,
            uri,
            total_supply,
            vector<bool>[true, true, true],
        );

        let available_tokens = simple_map::create();
        move_to(&resource_signer, CollectionState {
            signer_cap,
            available_tokens,
            total_supply,
            claimed_tokens: 0,
            paused: false,
            contract_address: @nft_collection,
        });
    }

    public entry fun add_token(
        admin: &signer,
        token_id: u64,
        name: String,
        description: String,
        uri: String,
    ) acquires CollectionState {
        add_token_internal(admin, token_id, name, description, uri);
    }

    public fun add_token_internal(
        admin: &signer,
        token_id: u64,
        name: String,
        description: String,
        uri: String,
    ) acquires CollectionState {
        let state = borrow_global_mut<CollectionState>(signer::address_of(admin));
        assert!(signer::address_of(admin) == @nft_collection, EINVALID_RESOURCE_ADDRESS);

        simple_map::add(&mut state.available_tokens, token_id, TokenMetadata {
            name,
            description,
            uri,
        });
    }

    #[randomness]
    entry fun claim_nft(
        claimer: &signer,
        resource_addr: address,
        collection_name: String,
    ) acquires CollectionState {
        claim_nft_internal(claimer, resource_addr, collection_name);
    }

    fun claim_nft_internal(
        claimer: &signer,
        resource_addr: address,
        collection_name: String,
    ) acquires CollectionState {
        let state = borrow_global_mut<CollectionState>(resource_addr);
        assert!(state.contract_address == @nft_collection, EINVALID_RESOURCE_ADDRESS);
        assert!(!state.paused, EPAUSED);
        assert!(state.claimed_tokens < state.total_supply, ESOLD_OUT);

        let rand_num = randomness::u64_range(0, state.total_supply);
        let token_id = find_available_token(rand_num, state);
        let (_, metadata) = simple_map::remove(&mut state.available_tokens, &token_id);

        let resource_signer = account::create_signer_with_capability(&state.signer_cap);
        token::create_token_script(
            &resource_signer,
            collection_name,
            metadata.name,
            metadata.description,
            1,
            0,
            metadata.uri,
            signer::address_of(claimer),
            0,
            0,
            vector<bool>[false, false, false, false, false],
            vector::empty<String>(),
            vector::empty<vector<u8>>(),
            vector::empty<String>(),
        );

        state.claimed_tokens = state.claimed_tokens + 1;
    }

    fun find_available_token(rand_num: u64, state: &CollectionState): u64 {
        let i = 0;
        
        while (i < state.total_supply) {
            if (simple_map::contains_key(&state.available_tokens, &i)) {
                if (rand_num == 0) {
                    return i
                };
                rand_num = rand_num - 1;
            };
            i = i + 1;
        };
        abort 999
    }

    public entry fun pause(admin: &signer, resource_addr: address) acquires CollectionState {
        pause_internal(admin, resource_addr);
    }

    public fun pause_internal(admin: &signer, resource_addr: address) acquires CollectionState {
        let state = borrow_global_mut<CollectionState>(resource_addr);
        assert!(state.contract_address == @nft_collection, EINVALID_RESOURCE_ADDRESS);
        assert!(signer::address_of(admin) == account::get_signer_capability_address(&state.signer_cap), 0);
        state.paused = true;
    }

    public entry fun unpause(admin: &signer, resource_addr: address) acquires CollectionState {
        unpause_internal(admin, resource_addr);
    }

    public fun unpause_internal(admin: &signer, resource_addr: address) acquires CollectionState {
        let state = borrow_global_mut<CollectionState>(resource_addr);
        assert!(state.contract_address == @nft_collection, EINVALID_RESOURCE_ADDRESS);
        assert!(signer::address_of(admin) == account::get_signer_capability_address(&state.signer_cap), 0);
        state.paused = false;
    }

    #[test_only]
    public fun init_test(admin: &signer, resource_addr: address) {
        initialize_internal(
            admin,
            resource_addr,
            utf8(b"Test Collection"),
            utf8(b"Test Description"),
            utf8(b"https://test.uri"),
            100
        );
    }

    #[test_only]
    #[lint::allow_unsafe_randomness]
    public fun claim_test(
        claimer: &signer,
        resource_addr: address,
    ) acquires CollectionState {
        claim_nft_internal(
            claimer,
            resource_addr,
            utf8(b"Test Collection")
        );
    }
}
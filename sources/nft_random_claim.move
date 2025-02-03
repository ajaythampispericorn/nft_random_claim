module nft_collection::random_nft {
    use std::string::{String, utf8};
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use aptos_framework::randomness;
    use aptos_token::token;
    use aptos_std::table::{Self, Table};

    const ESOLD_OUT: u64 = 2;
    const EPAUSED: u64 = 3;

    struct CollectionState has key {
        signer_cap: account::SignerCapability,
        available_tokens: Table<u64, TokenMetadata>,
        total_supply: u64,
        claimed_tokens: u64,
        paused: bool,
    }

    struct TokenMetadata has store {
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

        let available_tokens = table::new();
        move_to(&resource_signer, CollectionState {
            signer_cap,
            available_tokens,
            total_supply,
            claimed_tokens: 0,
            paused: false,
        });
    }

    public entry fun add_token(
        admin: &signer,
        token_id: u64,
        name: String,
        description: String,
        uri: String,
    ) acquires CollectionState {
        let admin_addr = account::get_signer_capability_address(&borrow_global<CollectionState>(
            resource_account::get_resource_address(signer::address_of(admin))
        ).signer_cap);
        assert!(signer::address_of(admin) == admin_addr, 0);

        let state = borrow_global_mut<CollectionState>(
            resource_account::get_resource_address(signer::address_of(admin))
        );
        table::add(&mut state.available_tokens, token_id, TokenMetadata {
            name,
            description,
            uri,
        });
    }

    public entry fun claim_random_nft(
        claimer: &signer,
        resource_addr: address,
        collection_name: String,
    ) acquires CollectionState {
        let state = borrow_global_mut<CollectionState>(resource_addr);
        assert!(!state.paused, EPAUSED);
        assert!(state.claimed_tokens < state.total_supply, ESOLD_OUT);

        // Use Aptos randomness to generate a seed
        let rand_num = randomness::u64_range(0, state.total_supply);
        
        let token_id = find_available_token(rand_num, state);
        let metadata = table::remove(&mut state.available_tokens, token_id);

        let resource_signer = account::create_signer_with_capability(&state.signer_cap);
        token::mint_token(
            &resource_signer,
            utf8(collection_name),
            metadata.name,
            metadata.description,
            1,
            metadata.uri,
            signer::address_of(claimer),
            vector::empty(),
            vector::empty(),
            vector::empty(),
        );

        state.claimed_tokens = state.claimed_tokens + 1;
    }

    fun find_available_token(rand_num: u64, state: &CollectionState): u64 {
        let i = 0;
        
        while (i < state.total_supply) {
            if (table::contains(&state.available_tokens, i)) {
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
        let state = borrow_global_mut<CollectionState>(resource_addr);
        assert!(signer::address_of(admin) == account::get_signer_capability_address(&state.signer_cap), 0);
        state.paused = true;
    }

    public entry fun unpause(admin: &signer, resource_addr: address) acquires CollectionState {
        let state = borrow_global_mut<CollectionState>(resource_addr);
        assert!(signer::address_of(admin) == account::get_signer_capability_address(&state.signer_cap), 0);
        state.paused = false;
    }
}
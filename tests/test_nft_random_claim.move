module nft_collection::random_nft_tests {
    use std::string;
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::resource_account;
    use aptos_framework::randomness;
    use nft_collection::random_nft;

    const RESOURCE_ADDR: address = @0x123;
    const COLLECTION_NAME: vector<u8> = b"Test NFT Collection";
    
    #[test(admin = @0x1, resource_account = @0x123)]
    public entry fun test_initialize(admin: signer, resource_account: signer) {
        timestamp::set_time_has_started_for_testing(&admin);
        
        resource_account::create_resource_account_and_publish_package(
            &admin,
            vector::empty(),
            vector::empty(),
        );
        
        random_nft::initialize(
            &admin,
            signer::address_of(&resource_account),
            string::utf8(COLLECTION_NAME),
            string::utf8(b"Test Description"),
            string::utf8(b"https://test.uri"),
            10
        );
    }

    #[test(admin = @0x1, resource_account = @0x123, claimer = @0x456)]
    public entry fun test_add_and_claim_token(
        admin: signer,
        resource_account: signer,
        claimer: signer
    ) {
        test_initialize(admin, resource_account);

        random_nft::add_token(
            &admin,
            0,
            string::utf8(b"Token #1"),
            string::utf8(b"First Token"),
            string::utf8(b"https://test.uri/1"),
        );

        random_nft::claim_random_nft(
            &claimer, 
            RESOURCE_ADDR, 
            string::utf8(COLLECTION_NAME)
        );
    }

    #[test(admin = @0x1, resource_account = @0x123, claimer = @0x456)]
    public entry fun test_multiple_token_claims(
        admin: signer,
        resource_account: signer,
        claimer: signer
    ) {
        test_initialize(admin, resource_account);

        // Add multiple tokens
        let tokens = vector[
            string::utf8(b"Token #1"),
            string::utf8(b"Token #2"),
            string::utf8(b"Token #3")
        ];

        vector::enumerate_with_index(tokens, |i, token_name| {
            random_nft::add_token(
                &admin,
                (i as u64),
                token_name,
                string::utf8(b"Token Description"),
                string::utf8(b"https://test.uri/token"),
            );
        });

        // Claim multiple tokens
        let i = 0;
        while (i < 3) {
            random_nft::claim_random_nft(
                &claimer, 
                RESOURCE_ADDR, 
                string::utf8(COLLECTION_NAME)
            );
            i = i + 1;
        };
    }

    #[test(admin = @0x1, resource_account = @0x123, claimer = @0x456)]
    #[expected_failure(abort_code = 2)]
    public entry fun test_claim_sold_out(
        admin: signer,
        resource_account: signer,
        claimer: signer
    ) {
        test_initialize(admin, resource_account);

        random_nft::add_token(
            &admin,
            0,
            string::utf8(b"Token #1"),
            string::utf8(b"First Token"),
            string::utf8(b"https://test.uri/1"),
        );

        // First claim should succeed
        random_nft::claim_random_nft(
            &claimer, 
            RESOURCE_ADDR, 
            string::utf8(COLLECTION_NAME)
        );
        
        // Second claim should fail with ESOLD_OUT
        random_nft::claim_random_nft(
            &claimer, 
            RESOURCE_ADDR, 
            string::utf8(COLLECTION_NAME)
        );
    }

    #[test(admin = @0x1, resource_account = @0x123, claimer = @0x456)]
    #[expected_failure(abort_code = 3)]
    public entry fun test_claim_when_paused(
        admin: signer,
        resource_account: signer,
        claimer: signer
    ) {
        test_initialize(admin, resource_account);

        random_nft::add_token(
            &admin,
            0,
            string::utf8(b"Token #1"),
            string::utf8(b"First Token"),
            string::utf8(b"https://test.uri/1"),
        );

        // Pause collection
        random_nft::pause(&admin, RESOURCE_ADDR);
        
        // Attempt to claim while paused (should fail)
        random_nft::claim_random_nft(
            &claimer, 
            RESOURCE_ADDR, 
            string::utf8(COLLECTION_NAME)
        );
    }
}
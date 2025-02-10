#[test_only]
module nft_collection::random_nft_tests {
    // Previous imports and constants remain the same...
    use std::signer;
    use std::string;
    use std::error;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::randomness;
    use nft_collection::random_nft;

    // Error codes for tests (matching main module's actual error codes)
    const ENFT_ALREADY_EXISTS: u64 = 0x50001;  // 851969
    const ENFT_DOES_NOT_EXIST: u64 = 0x40001;  // 655361
    const ENOT_OWNER: u64 = 0x30001;  // 524289
    const ECOLLECTION_NOT_INITIALIZED: u64 = 0x40002;  // 655362
    const EALL_TOKENS_CLAIMED: u64 = 0x60001;  // 917505

    // Test setup helper
    fun setup(aptos_framework: &signer, admin: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        // Initialize randomness - ignore errors if already initialized
        randomness::initialize_for_testing(aptos_framework);
        random_nft::initialize_for_test(admin);
    }

    #[test(aptos_framework = @0x1, admin = @nft_collection)]
    #[lint::allow_unsafe_randomness]
    public fun test_init_module(aptos_framework: &signer, admin: &signer) {
        setup(aptos_framework, admin);
        let admin_addr = signer::address_of(admin);

        assert!(random_nft::test_has_resource_cap(admin_addr), 0);
        let resource_account_address = random_nft::test_get_resource_account_address(admin_addr);
        assert!(random_nft::test_has_collection(resource_account_address), 0);

        assert!(random_nft::get_total_supply() == 100, 0);
        assert!(random_nft::get_minted() == 0, 0);
    }

    #[test(aptos_framework = @0x1, admin = @nft_collection)]
    #[lint::allow_unsafe_randomness]
    public fun test_add_nft_success(aptos_framework: &signer, admin: &signer) {
        setup(aptos_framework, admin);

        let token_id = 1;
        let name = string::utf8(b"Test NFT");
        let description = string::utf8(b"Test Description");
        let uri = string::utf8(b"https://test.uri");
        
        random_nft::add_nft(admin, token_id, name, description, uri);

        let (saved_name, saved_desc, saved_uri) = random_nft::get_nft_info(token_id);
        assert!(saved_name == name, 0);
        assert!(saved_desc == description, 0);
        assert!(saved_uri == uri, 0);
    }

    #[test(aptos_framework = @0x1, admin = @nft_collection, user = @0x456)]
    #[expected_failure(abort_code = 524289, location = nft_collection::random_nft)]
    #[lint::allow_unsafe_randomness]
    public fun test_add_nft_not_admin(aptos_framework: &signer, admin: &signer, user: &signer) {
        setup(aptos_framework, admin);

        random_nft::add_nft(
            user, 
            1, 
            string::utf8(b"Test NFT"),
            string::utf8(b"Test Description"),
            string::utf8(b"https://test.uri")
        );
    }

    #[test(aptos_framework = @0x1, admin = @nft_collection)]
    #[expected_failure(abort_code = 851969, location = nft_collection::random_nft)]
    #[lint::allow_unsafe_randomness]
    public fun test_add_nft_duplicate(aptos_framework: &signer, admin: &signer) {
        setup(aptos_framework, admin);

        let name = string::utf8(b"Test NFT");
        let description = string::utf8(b"Test Description");
        let uri = string::utf8(b"https://test.uri");
        
        random_nft::add_nft(admin, 1, copy name, copy description, copy uri);
        random_nft::add_nft(admin, 1, name, description, uri);
    }

    #[test(aptos_framework = @0x1, admin = @nft_collection, user = @0x456)]
    #[lint::allow_unsafe_randomness]
    public fun test_claim_random_nft_success(aptos_framework: &signer, admin: &signer, user: &signer) {
        setup(aptos_framework, admin);

        random_nft::add_nft(
            admin, 
            0,
            string::utf8(b"NFT 0"),
            string::utf8(b"Description 0"),
            string::utf8(b"https://test.uri/0")
        );

        random_nft::add_nft(
            admin,
            1,
            string::utf8(b"NFT 1"),
            string::utf8(b"Description 1"),
            string::utf8(b"https://test.uri/1")
        );

        random_nft::claim_random_nft(user);
        assert!(random_nft::get_minted() == 1, 0);
    }

    #[test(aptos_framework = @0x1, admin = @nft_collection, user1 = @0x456, user2 = @0x789)]
    #[lint::allow_unsafe_randomness]
    #[expected_failure(abort_code = 917505, location = nft_collection::random_nft)]
    public fun test_claim_nft_all_claimed(aptos_framework: &signer, admin: &signer, user1: &signer, user2: &signer) {
        setup(aptos_framework, admin);

        // Add maximum number of NFTs that can be minted (should match total_supply)
        let i = 0;
        let total_supply = random_nft::get_total_supply();
        while (i < total_supply) {
            random_nft::add_nft(
                admin,
                i,
                string::utf8(b"NFT"),
                string::utf8(b"Description"),
                string::utf8(b"https://test.uri")
            );
            i = i + 1;
        };

        // Claim all NFTs
        let j = 0;
        while (j < total_supply) {
            random_nft::claim_random_nft(user1);
            j = j + 1;
        };

        // Try to claim one more (should fail)
        random_nft::claim_random_nft(user2);
    }

    #[test(aptos_framework = @0x1, admin = @nft_collection)]
    #[expected_failure(abort_code = 655361, location = nft_collection::random_nft)]
    #[lint::allow_unsafe_randomness]
    public fun test_get_nft_info_nonexistent(aptos_framework: &signer, admin: &signer) {
        setup(aptos_framework, admin);
        random_nft::get_nft_info(999);
    }

    #[test(aptos_framework = @0x1, admin = @nft_collection, user1 = @0x456, user2 = @0x789)]
    #[lint::allow_unsafe_randomness]
    public fun test_multiple_users_claim(
        aptos_framework: &signer, 
        admin: &signer,
        user1: &signer,
        user2: &signer
    ) {
        setup(aptos_framework, admin);

        let i = 0;
        while (i < 5) {
            random_nft::add_nft(
                admin,
                i,
                string::utf8(b"NFT"),
                string::utf8(b"Description"),
                string::utf8(b"https://test.uri")
            );
            i = i + 1;
        };

        random_nft::claim_random_nft(user1);
        random_nft::claim_random_nft(user2);
        assert!(random_nft::get_minted() == 2, 0);
    }
}
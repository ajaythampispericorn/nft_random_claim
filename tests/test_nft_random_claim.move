#[test_only]
module nft_collection::nft_claim_tests {
    use std::signer;
    use std::string;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::randomness;
    use nft_collection::random_nft;

    // Error constants matching the ones in random_nft module
    const ENFT_ALREADY_EXISTS: u64 = 0xD0001; // 851969 in decimal
    const ENOT_OWNER: u64 = 0x80001; // 524289 in decimal
    const ENFT_DOES_NOT_EXIST: u64 = 0x40001;
    const ECOLLECTION_NOT_INITIALIZED: u64 = 0x40002;
    const EALL_TOKENS_CLAIMED: u64 = 0x90001; // 589825 in decimal

    // Test helper function to create test addresses and signers
    fun create_test_signer(addr: address): signer {
        account::create_account_for_test(addr)
    }

    // Helper to set up aptos framework account with all necessary resources
    fun setup_aptos_framework(): signer {
        let framework_signer = create_test_signer(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);
        randomness::initialize_for_testing(&framework_signer);
        framework_signer
    }

    #[test]
    fun test_initialize_collection() {
        setup_aptos_framework();
        let admin = create_test_signer(@nft_collection);
        random_nft::initialize_for_test(&admin);
        assert!(random_nft::test_has_resource_cap(@nft_collection), 0);
        
        let resource_account_addr = random_nft::test_get_resource_account_address(@nft_collection);
        assert!(random_nft::test_has_collection(resource_account_addr), 0);
    }

    #[test]
    fun test_add_nft_success() {
        setup_aptos_framework();
        let admin = create_test_signer(@nft_collection);
        random_nft::initialize_for_test(&admin);
        
        let name = string::utf8(b"Test NFT");
        let description = string::utf8(b"Test Description");
        let uri = string::utf8(b"https://test.uri");
        
        random_nft::add_nft(&admin, 1, name, description, uri);
        
        let (returned_name, returned_desc, returned_uri) = random_nft::get_nft_info(1);
        assert!(returned_name == name, 0);
        assert!(returned_desc == description, 0);
        assert!(returned_uri == uri, 0);
    }

    #[test]
    #[expected_failure(abort_code = 0xD0001)] // ENFT_ALREADY_EXISTS
    fun test_add_nft_failure_duplicate() {
        setup_aptos_framework();
        let admin = create_test_signer(@nft_collection);
        random_nft::initialize_for_test(&admin);
        
        let name = string::utf8(b"Test NFT");
        let description = string::utf8(b"Test Description");
        let uri = string::utf8(b"https://test.uri");
        
        random_nft::add_nft(&admin, 1, name, description, uri);
        random_nft::add_nft(&admin, 1, name, description, uri); // Should fail with ENFT_ALREADY_EXISTS
    }

    #[test]
    fun test_claim_random_nft() {
        let framework_signer = setup_aptos_framework();
        
        // Initialize collection and add NFTs
        let admin = create_test_signer(@nft_collection);
        random_nft::initialize_for_test(&admin);
        
        let name = string::utf8(b"Test NFT");
        let description = string::utf8(b"Test Description");
        let uri = string::utf8(b"https://test.uri");
        
        // Add multiple NFTs to ensure random selection works
        let i = 0;
        while (i < 10) {
            random_nft::add_nft(&admin, i, name, description, uri);
            i = i + 1;
        };
        
        let user = create_test_signer(@0x123);
        random_nft::claim_random_nft(&user);
        
        assert!(random_nft::get_minted() == 1, 0);
    }

    #[test]
    #[expected_failure(abort_code = 0x80001)] // ENOT_OWNER
    fun test_only_admin_can_add_nft() {
        setup_aptos_framework();
        let admin = create_test_signer(@nft_collection);
        random_nft::initialize_for_test(&admin);
        
        let user = create_test_signer(@0x123);
        let name = string::utf8(b"Test NFT");
        let description = string::utf8(b"Test Description");
        let uri = string::utf8(b"https://test.uri");
        
        random_nft::add_nft(&user, 1, name, description, uri); // Should fail with ENOT_OWNER
    }

    #[test]
    #[expected_failure(abort_code = 0x90001)] // EALL_TOKENS_CLAIMED
    fun test_all_tokens_claimed() {
        let framework_signer = setup_aptos_framework();
        let admin = create_test_signer(@nft_collection);
        random_nft::initialize_for_test(&admin);
        
        let name = string::utf8(b"Test NFT");
        let description = string::utf8(b"Test Description");
        let uri = string::utf8(b"https://test.uri");
        
        // Add all possible tokens
        let i = 0;
        while (i < 100) {
            random_nft::add_nft(&admin, i, name, description, uri);
            i = i + 1;
        };
        
        let user = create_test_signer(@0x123);
        
        // Try to claim more than total supply
        i = 0;
        while (i < 101) {
            random_nft::claim_random_nft(&user);
            i = i + 1;
        };
    }

    #[test]
    fun test_get_total_supply() {
        setup_aptos_framework();
        let admin = create_test_signer(@nft_collection);
        random_nft::initialize_for_test(&admin);
        assert!(random_nft::get_total_supply() == 100, 0);
    }
}
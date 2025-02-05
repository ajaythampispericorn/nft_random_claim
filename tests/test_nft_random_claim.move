#[test_only]
module nft_collection::random_nft_tests {
    use std::string::{Self, String};
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::randomness;
    use nft_collection::random_nft;

    // Test addresses
    const USER1_ADDR: address = @0x123;
    const USER2_ADDR: address = @0x456;
    const USER3_ADDR: address = @0x789;
    const USER4_ADDR: address = @0x321;
    const USER5_ADDR: address = @0x654;

    // Error constants (matching the actual error codes from the contract)
    const ENFT_ALREADY_EXISTS: u64 = 524289; // 0x80001
    const ENFT_DOES_NOT_EXIST: u64 = 393218; // 0x60002
    const EALL_TOKENS_CLAIMED: u64 = 393221; // 0x60005

    // Helper function to set up module account
    fun setup_module_account(module_account: &signer) {
        account::create_account_for_test(signer::address_of(module_account));
    }

    // Helper function to initialize randomness for testing
    fun initialize_randomness(framework: &signer) {
        // First create and initialize the account
        account::create_account_for_test(@aptos_framework);
        randomness::initialize_for_testing(framework);
    }

    // Helper function to create test accounts
    fun create_test_account(addr: address): signer {
        account::create_account_for_test(addr)
    }

    fun create_nft_data(id: u64): (String, String, String) {
        (
            string::utf8(b"NFT Name #"),
            string::utf8(b"Description for NFT #"),
            string::utf8(b"https://nft.uri/")
        )
    }

    // Initialize the collection and add NFTs
    fun setup_nfts(admin: &signer, framework: &signer, count: u64) {
        setup_module_account(admin);
        initialize_randomness(framework);
        random_nft::initialize_for_test(admin);
        let i = 0;
        while (i < count) {
            let (name, desc, uri) = create_nft_data(i);
            random_nft::add_nft(admin, i, name, desc, uri);
            i = i + 1;
        }
    }

    // Test NFT addition
    #[test(admin = @nft_collection)]
    fun test_add_nft_success(admin: signer) {
        setup_module_account(&admin);
        random_nft::initialize_for_test(&admin);
        let (name, desc, uri) = create_nft_data(0);
        random_nft::add_nft(&admin, 0, name, desc, uri);
        
        let (stored_name, stored_desc, stored_uri) = random_nft::get_nft_info(0);
        assert!(stored_name == name, 0);
        assert!(stored_desc == desc, 1);
        assert!(stored_uri == uri, 2);
    }

    // Test adding duplicate NFT
    #[test(admin = @nft_collection)]
    #[expected_failure(abort_code = ENFT_ALREADY_EXISTS, location = nft_collection::random_nft)]
    fun test_add_duplicate_nft(admin: signer) {
        setup_module_account(&admin);
        random_nft::initialize_for_test(&admin);
        let (name, desc, uri) = create_nft_data(0);
        random_nft::add_nft(&admin, 0, name, desc, uri);
        random_nft::add_nft(&admin, 0, name, desc, uri);
    }

    // Test claiming NFT
    #[test(admin = @nft_collection, framework = @aptos_framework)]
    fun test_claim_nft(admin: signer, framework: signer) {
        setup_nfts(&admin, &framework, 5);
        timestamp::set_time_has_started_for_testing(&framework);
        
        let user = create_test_account(USER1_ADDR);
        let initial_minted = random_nft::get_minted();
        random_nft::claim_random_nft(&user);
        
        assert!(random_nft::get_minted() == initial_minted + 1, 0);
    }

    // Test claiming with no available tokens
    #[test(admin = @nft_collection, framework = @aptos_framework)]
    #[expected_failure(abort_code = EALL_TOKENS_CLAIMED, location = nft_collection::random_nft)]
    fun test_claim_no_available_tokens(admin: signer, framework: signer) {
        // Create only one NFT
        setup_nfts(&admin, &framework, 1);
        timestamp::set_time_has_started_for_testing(&framework);
        
        let user1 = create_test_account(USER1_ADDR);
        
        // First try to claim the NFT
        random_nft::claim_random_nft(&user1);
        
        // Try to claim again when no tokens are available
        random_nft::claim_random_nft(&user1); // Should fail with EALL_TOKENS_CLAIMED
    }

    // Test get_nft_info for non-existent token
    #[test(admin = @nft_collection)]
    #[expected_failure(abort_code = ENFT_DOES_NOT_EXIST, location = nft_collection::random_nft)]
    fun test_get_nonexistent_nft(admin: signer) {
        setup_module_account(&admin);
        random_nft::initialize_for_test(&admin);
        random_nft::get_nft_info(999);
    }

    // Test multiple claims with different users
    #[test(admin = @nft_collection, framework = @aptos_framework)]
    fun test_random_distribution(admin: signer, framework: signer) {
        setup_nfts(&admin, &framework, 10);
        timestamp::set_time_has_started_for_testing(&framework);
        
        let user1 = create_test_account(USER1_ADDR);
        let user2 = create_test_account(USER2_ADDR);
        let user3 = create_test_account(USER3_ADDR);
        let user4 = create_test_account(USER4_ADDR);
        let user5 = create_test_account(USER5_ADDR);
        
        random_nft::claim_random_nft(&user1);
        random_nft::claim_random_nft(&user2);
        random_nft::claim_random_nft(&user3);
        random_nft::claim_random_nft(&user4);
        random_nft::claim_random_nft(&user5);
        
        assert!(random_nft::get_minted() == 5, 0);
    }

    // Test supply and minted count
    #[test(admin = @nft_collection, framework = @aptos_framework)]
    fun test_supply_and_minted(admin: signer, framework: signer) {
        setup_nfts(&admin, &framework, 5);
        timestamp::set_time_has_started_for_testing(&framework);
        
        assert!(random_nft::get_total_supply() == 100, 0);
        assert!(random_nft::get_minted() == 0, 1);
        
        let user = create_test_account(USER1_ADDR);
        random_nft::claim_random_nft(&user);
        
        assert!(random_nft::get_total_supply() == 100, 2);
        assert!(random_nft::get_minted() == 1, 3);
    }
}
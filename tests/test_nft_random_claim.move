#[test_only]
module nft_collection::random_nft_tests {
    use std::string::{Self, String};
    use std::signer;
    use std::vector;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::timestamp;
    use aptos_framework::resource_account;
    use nft_collection::random_nft::{Self, CollectionState};

    const RESOURCE_ACCOUNT: address = @nft_collection;

    fun setup(aptos: &signer, admin: &signer) {
        timestamp::set_time_has_started_for_testing(aptos);
        
        // Create the admin account
        account::create_account_for_test(RESOURCE_ACCOUNT);
        
        // Create the resource account with a seed and fund it
        let seed = vector::empty<u8>();
        vector::append(&mut seed, b"SEED_1234");
        let resource_signer = account::create_account_for_test(RESOURCE_ACCOUNT);
        
        // Create and retrieve the resource account signer capability
        let resource_cap = resource_account::create_resource_account_and_fund(
            admin,            // Source account signer
            vector::empty<u8>(), // Optional capability offer
            seed,            // Seed for resource account
            vector::empty<u8>(), // Optional metadata serialized
        );
    }

    #[test(admin = @nft_collection, aptos = @aptos_framework)]
    fun test_initialize_success(admin: &signer, aptos: &signer) {
        setup(aptos, admin);
        
        random_nft::init_test(
            admin,
            RESOURCE_ACCOUNT,
        );
    }

    #[test(admin = @nft_collection, aptos = @aptos_framework)]
    #[expected_failure(abort_code = 4, location = nft_collection::random_nft)]
    fun test_initialize_invalid_resource_address(admin: &signer, aptos: &signer) {
        setup(aptos, admin);

        random_nft::initialize_internal(
            admin,
            @0x123,  // Invalid resource address
            string::utf8(b"Test Collection"),
            string::utf8(b"Test Description"),
            string::utf8(b"https://test.uri"),
            100
        );
    }

    #[test(admin = @nft_collection, aptos = @aptos_framework)]
    fun test_add_token_success(admin: &signer, aptos: &signer) {
        setup(aptos, admin);

        random_nft::init_test(
            admin,
            RESOURCE_ACCOUNT,
        );

        random_nft::add_token_internal(
            admin,
            1,
            string::utf8(b"Token #1"),
            string::utf8(b"Token Description"),
            string::utf8(b"https://token1.uri")
        );
    }

    #[test(admin = @nft_collection, other = @0x2, aptos = @aptos_framework)]
    #[expected_failure(abort_code = 4, location = nft_collection::random_nft)]
    fun test_add_token_invalid_admin(admin: &signer, other: &signer, aptos: &signer) {
        setup(aptos, admin);
        account::create_account_for_test(signer::address_of(other));

        random_nft::init_test(
            admin,
            RESOURCE_ACCOUNT,
        );

        random_nft::add_token_internal(
            other,
            1,
            string::utf8(b"Token #1"),
            string::utf8(b"Token Description"),
            string::utf8(b"https://token1.uri")
        );
    }

    #[test(admin = @nft_collection, claimer = @0x2, aptos = @aptos_framework)]
    #[lint::allow_unsafe_randomness]
    fun test_claim_nft_success(admin: &signer, claimer: &signer, aptos: &signer) {
        setup(aptos, admin);
        account::create_account_for_test(signer::address_of(claimer));

        random_nft::init_test(
            admin,
            RESOURCE_ACCOUNT,
        );

        random_nft::add_token_internal(
            admin,
            0,
            string::utf8(b"Token #1"),
            string::utf8(b"Token Description"),
            string::utf8(b"https://token1.uri")
        );

        random_nft::claim_test(
            claimer,
            RESOURCE_ACCOUNT,
        );
    }

    #[test(admin = @nft_collection, claimer = @0x2, aptos = @aptos_framework)]
    #[expected_failure(abort_code = 3, location = nft_collection::random_nft)]
    #[lint::allow_unsafe_randomness]
    fun test_claim_nft_paused(admin: &signer, claimer: &signer, aptos: &signer) {
        setup(aptos, admin);
        account::create_account_for_test(signer::address_of(claimer));

        random_nft::init_test(
            admin,
            RESOURCE_ACCOUNT,
        );

        random_nft::add_token_internal(
            admin,
            0,
            string::utf8(b"Token #1"),
            string::utf8(b"Token Description"),
            string::utf8(b"https://token1.uri")
        );

        random_nft::pause_internal(admin, RESOURCE_ACCOUNT);

        random_nft::claim_test(
            claimer,
            RESOURCE_ACCOUNT,
        );
    }

    #[test(admin = @nft_collection, claimer = @0x2, aptos = @aptos_framework)]
    #[expected_failure(abort_code = 2, location = nft_collection::random_nft)]
    #[lint::allow_unsafe_randomness]
    fun test_claim_nft_sold_out(admin: &signer, claimer: &signer, aptos: &signer) {
        setup(aptos, admin);
        account::create_account_for_test(signer::address_of(claimer));

        // Initialize with total supply of 1
        random_nft::initialize_internal(
            admin,
            RESOURCE_ACCOUNT,
            string::utf8(b"Test Collection"),
            string::utf8(b"Test Description"),
            string::utf8(b"https://test.uri"),
            1
        );

        random_nft::add_token_internal(
            admin,
            0,
            string::utf8(b"Token #1"),
            string::utf8(b"Token Description"),
            string::utf8(b"https://token1.uri")
        );

        // Claim the only available token
        random_nft::claim_test(
            claimer,
            RESOURCE_ACCOUNT,
        );

        // Try to claim again when sold out
        random_nft::claim_test(
            claimer,
            RESOURCE_ACCOUNT,
        );
    }

    #[test(admin = @nft_collection, claimer = @0x2, aptos = @aptos_framework)]
    #[expected_failure(abort_code = 4, location = nft_collection::random_nft)]
    #[lint::allow_unsafe_randomness]
    fun test_claim_nft_invalid_resource_address(admin: &signer, claimer: &signer, aptos: &signer) {
        setup(aptos, admin);
        account::create_account_for_test(signer::address_of(claimer));

        random_nft::init_test(
            admin,
            RESOURCE_ACCOUNT,
        );

        random_nft::add_token_internal(
            admin,
            0,
            string::utf8(b"Token #1"),
            string::utf8(b"Token Description"),
            string::utf8(b"https://token1.uri")
        );

        random_nft::claim_test(
            claimer,
            @0x123  // Invalid resource address
        );
    }

    #[test(admin = @nft_collection, aptos = @aptos_framework)]
    fun test_pause_unpause_success(admin: &signer, aptos: &signer) {
        setup(aptos, admin);

        random_nft::init_test(
            admin,
            RESOURCE_ACCOUNT,
        );

        random_nft::pause_internal(admin, RESOURCE_ACCOUNT);
        random_nft::unpause_internal(admin, RESOURCE_ACCOUNT);
    }

    #[test(admin = @nft_collection, other = @0x2, aptos = @aptos_framework)]
    #[expected_failure(abort_code = 0, location = nft_collection::random_nft)]
    fun test_pause_invalid_admin(admin: &signer, other: &signer, aptos: &signer) {
        setup(aptos, admin);
        account::create_account_for_test(signer::address_of(other));

        random_nft::init_test(
            admin,
            RESOURCE_ACCOUNT,
        );

        random_nft::pause_internal(other, RESOURCE_ACCOUNT);
    }

    #[test(admin = @nft_collection, other = @0x2, aptos = @aptos_framework)]
    #[expected_failure(abort_code = 0, location = nft_collection::random_nft)]
    fun test_unpause_invalid_admin(admin: &signer, other: &signer, aptos: &signer) {
        setup(aptos, admin);
        account::create_account_for_test(signer::address_of(other));

        random_nft::init_test(
            admin,
            RESOURCE_ACCOUNT,
        );

        random_nft::pause_internal(admin, RESOURCE_ACCOUNT);
        random_nft::unpause_internal(other, RESOURCE_ACCOUNT);
    }
}
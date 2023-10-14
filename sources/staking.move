module nft_skaking_addr::staking {

    use aptos_std::table::{Self, Table};
    use std::string::{String};
    use aptos_token::token::{Self, TokenId};
    use aptos_framework::timestamp;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::resource_account;
    use std::signer;
    use std::vector;
    use std::error;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::coin;
    use aptos_framework::event::{Self};
    // use aptos_std::debug;

    // Constants
    const EMMISSION_RATE: u64 = 1;

    // Errors
    const ETOKEN_ALREADY_STAKED: u64 = 0;
    const ETOKEN_NOT_FOUND: u64 = 1;
    const ENOT_ADMIN: u64 = 2;

    // Stores information about the staked token
    struct StakeInfo has store, drop, copy {
        pendingRewards: u64,
        startTime: u64,
        last_updated: u64,
    }

    // Holds all staked tokens information and related events
    struct UserStakeInfo has key {
        stakes: Table<TokenId, StakeInfo>,
        stake_event: event::EventHandle<StakeInfo>,
        unstake_event: event::EventHandle<StakeInfo>,
        claim_rewards_event: event::EventHandle<StakeInfo>
    }

    // Holds signer cap of resource account
    struct ModuleData has key {
        signer_cap: SignerCapability,
    }

    fun init_module(resource_signer: &signer) {
        // store resource signer cap under resource account for later use 
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @source_addr);
        move_to(resource_signer, ModuleData {
            signer_cap: resource_signer_cap,
        });
    }

    public fun register_stake(staker: &signer) {
        // creates a new userStakeInfo table under staker account
        let userStakeInfo = UserStakeInfo {
            stakes: table::new(),
            stake_event: account::new_event_handle<StakeInfo>(staker),
            unstake_event: account::new_event_handle<StakeInfo>(staker),
            claim_rewards_event: account::new_event_handle<StakeInfo>(staker)
        };

        move_to(staker, userStakeInfo);
    }

    public entry fun stake(account: &signer, creator: address, collection_name: String, token_name: String, token_property_version: u64) acquires ModuleData, UserStakeInfo {

        // borrow resource account signer cap
        let module_data = borrow_global_mut<ModuleData>(@nft_skaking_addr);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);

        let signer_address = signer::address_of(account);
        let resource_account_address = signer::address_of(&resource_signer);

        // opt in direct transfer by resource account
        token::opt_in_direct_transfer(&resource_signer, true);  

        // transfer nft to resource account from staker
        token::transfer_with_opt_in(account, creator, collection_name, token_name, token_property_version, resource_account_address,  1);

        let token_id = token::create_token_id_raw(creator, collection_name, token_name, token_property_version);

        // register if user is staking for the first time
        if (!exists<UserStakeInfo>(signer_address)) {
            register_stake(account);
        };

        let userStakeInfo = borrow_global_mut<UserStakeInfo>(signer_address);

        assert!(!table::contains(&userStakeInfo.stakes, token_id), error::invalid_argument(ETOKEN_ALREADY_STAKED));

        // create a corresponding StakeInfo for user
        let stake_info = StakeInfo {
            pendingRewards: 0, 
            startTime: timestamp::now_seconds(),
            last_updated: timestamp::now_seconds(),
        };

        // add stake_info to stakes list
        table::upsert(&mut userStakeInfo.stakes, token_id, copy stake_info);

        // emit a stake event
        event::emit_event<StakeInfo>(
            &mut borrow_global_mut<UserStakeInfo>(signer_address).stake_event,
            stake_info,
        );

    }

    public fun update_rewards(stake_record: &mut StakeInfo)  {
        // update pending rewards based on time
        let current_time = timestamp::now_seconds();
        stake_record.pendingRewards = stake_record.pendingRewards + get_pending_rewards(current_time, stake_record.last_updated);
        // debug::print<u64>(&stake_record.pendingRewards);
        stake_record.last_updated = current_time;
    }

    // Simple liner funtion based on time to calculate staking rewards.
    // This can be update to have complex reward calculation
    fun get_pending_rewards(current_time: u64, last_updated: u64): u64 {
        (current_time - last_updated) * EMMISSION_RATE
    }

    public fun claimRewards(staker: &signer, token_id: TokenId) acquires ModuleData, UserStakeInfo {
        // register staker to recieve coins
        coin::register<AptosCoin>(staker);

        // borrow signer cap of resource account
        let module_data = borrow_global_mut<ModuleData>(@nft_skaking_addr);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);

        let staker_address = signer::address_of(staker);
        let userStakeInfo = borrow_global_mut<UserStakeInfo>(staker_address);

        // ensure token is actually staked
        assert!(table::contains(&userStakeInfo.stakes, token_id), error::not_found(ETOKEN_NOT_FOUND));

        let stake_record = table::borrow_mut(&mut userStakeInfo.stakes, token_id);

        // update the rewards for token
        update_rewards(stake_record);

        // emit a claim reward event
        event::emit_event<StakeInfo>(
            &mut userStakeInfo.claim_rewards_event,
            *stake_record,
        );

        // transfer the calculated reward coins to staker
        coin::transfer<AptosCoin>(&resource_signer, staker_address, stake_record.pendingRewards);

        // zero out the pending rewards as all rewards have been sent
        stake_record.pendingRewards = 0;   
    }

    // entry function for user to claim rewards for a token anytime
    public entry fun claimRewardsForUser(staker: &signer, creator: address, collection_name: String, token_name: String, token_property_version: u64)  acquires ModuleData, UserStakeInfo {
        let token_id = token::create_token_id_raw(
            creator,
            collection_name,
            token_name,
            token_property_version,
        );

        claimRewards(staker, token_id);
    }

    public entry fun unstake(staker: &signer, creator: address, collection_name: String, token_name: String, token_property_version: u64) acquires ModuleData, UserStakeInfo {

        // borrow signer cap for resource account
        let module_data = borrow_global_mut<ModuleData>(@nft_skaking_addr);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);

        let token_id = token::create_token_id_raw(creator, collection_name, token_name, token_property_version);

        let staker_address = signer::address_of(staker);

        // claim the rewards for given token
        claimRewards(staker, token_id);

        // enable direct transfer in staker end
        token::opt_in_direct_transfer(staker, true);

        // transfer the nft back from resource account to staker
        token::transfer_with_opt_in(&resource_signer, creator, collection_name, token_name, token_property_version, staker_address,  1);

        // remove the stake information from staker account
        let userStakeInfo = borrow_global_mut<UserStakeInfo>(staker_address);
        let stake_record = table::remove(&mut userStakeInfo.stakes, token_id);

        // emit a unstake event
        event::emit_event<StakeInfo>(
            &mut borrow_global_mut<UserStakeInfo>(staker_address).unstake_event,
            stake_record,
        );
    }

    // admin function to deposit reward coins
    public entry fun deposit_funds(admin: &signer, amount: u64) acquires ModuleData {

        // ensure the caller is admin
        let admin_address = signer::address_of(admin);
        assert!(admin_address == @admin_addr, error::permission_denied(ENOT_ADMIN));

        // get resource account address
        let module_data = borrow_global_mut<ModuleData>(@nft_skaking_addr);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
        let resource_account_address = signer::address_of(&resource_signer);

        // transfer coins from admin to resource account
        coin::register<AptosCoin>(&resource_signer);
        coin::transfer<AptosCoin>(admin, resource_account_address, amount);
    }

    // admin function to withdraw funds if required
    public entry fun withdraw_funds(admin: &signer, amount: u64) acquires ModuleData {

        // ensure the caller is admin
        let admin_address = signer::address_of(admin);
        assert!(admin_address == @admin_addr, error::permission_denied(ENOT_ADMIN));

        // borrow signer cap of resource account
        let module_data = borrow_global_mut<ModuleData>(@nft_skaking_addr);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);

        // transfer coins from resource account to admin
        coin::register<AptosCoin>(admin);
        coin::transfer<AptosCoin>(&resource_signer, admin_address, amount);
    }

    // [view]

    // function to get amount of reward coins in the protocol
    public fun get_funds() : u64 acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@nft_skaking_addr);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
        let resource_account_address = signer::address_of(&resource_signer);

        coin::balance<AptosCoin>(resource_account_address)
    }

    // function to view pending rewards of a token the user staked
    public fun view_pending_rewards(staker_address: address, token_id: TokenId): u64 acquires UserStakeInfo {
        let userStakeInfo = borrow_global<UserStakeInfo>(staker_address);

        assert!(table::contains(&userStakeInfo.stakes, token_id), error::not_found(ETOKEN_NOT_FOUND));

        let stake_record = table::borrow(&userStakeInfo.stakes, token_id);
        stake_record.pendingRewards
    }

    #[test_only]
    public fun set_up_test(
        origin_account: &signer,
        resource_account: &signer,
        admin: &signer,
        creator: &signer,
        nft_staker: &signer,
    ) {

        account::create_account_for_test(signer::address_of(origin_account));
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(creator));
        account::create_account_for_test(signer::address_of(nft_staker));

        resource_account::create_resource_account(origin_account, vector::empty<u8>(), vector::empty<u8>());
        init_module(resource_account);
    }

    #[test_only]
    public fun create_collection_and_token(
        creator: &signer,
        amount: u64,
        collection_max: u64,
        token_max: u64,
        property_keys: vector<String>,
        property_values: vector<vector<u8>>,
        property_types: vector<String>,
        collection_mutate_setting: vector<bool>,
        token_mutate_setting: vector<bool>,
    ): TokenId {
        use std::string;
        use std::bcs;
        let mutate_setting = collection_mutate_setting;

        token::create_collection(
            creator,
            token::get_collection_name(),
            string::utf8(b"Collection: Hello, World"),
            string::utf8(b"https://aptos.dev"),
            collection_max,
            mutate_setting
        );

        let default_keys = if (vector::length<String>(&property_keys) == 0) { vector<String>[string::utf8(b"attack"), string::utf8(b"num_of_use")] } else { property_keys };
        let default_vals = if (vector::length<vector<u8>>(&property_values) == 0) { vector<vector<u8>>[bcs::to_bytes<u64>(&10), bcs::to_bytes<u64>(&5)] } else { property_values };
        let default_types = if (vector::length<String>(&property_types) == 0) { vector<String>[string::utf8(b"u64"), string::utf8(b"u64")] } else { property_types };
        let mutate_setting = token_mutate_setting;

        token::create_token_script(
            creator,
            token::get_collection_name(),
            token::get_token_name(),
            string::utf8(b"Hello, Token"),
            amount,
            token_max,
            string::utf8(b"https://aptos.dev"),
            signer::address_of(creator),
            100,
            0,
            mutate_setting,
            default_keys,
            default_vals,
            default_types,
        );
        token::create_token_id_raw(signer::address_of(creator), token::get_collection_name(), token::get_token_name(), 0)
    }

    #[test_only]
    public fun set_up_mint_coins(
        admin: &signer,
        resource_account: &signer,
        aptos_framework: &signer,
    ) { 

        timestamp::set_time_has_started_for_testing(aptos_framework);

        let resource_account_address = signer::address_of(resource_account);
        let admin_address = signer::address_of(admin);

        // intialize with some fund in the admin account
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let coins = coin::mint(1000, &mint_cap);
        coin::register<AptosCoin>(admin);
        coin::register<AptosCoin>(resource_account);
        coin::deposit<AptosCoin>(admin_address, coins);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        assert!(coin::balance<AptosCoin>(admin_address) == 1000, 1);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 0, 1);
    }

    #[test_only]
    public fun setup_up_create_collection_and_token(creator: &signer, nft_staker: &signer): TokenId {
        let token_id = create_collection_and_token(
            creator,
            1,
            2,
            1,
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
            vector<bool>[false, false, false],
            vector<bool>[false, false, false, false, false],
        );

        let creator_address = signer::address_of(creator);
        let nft_staker_address = signer::address_of(nft_staker);
        token::opt_in_direct_transfer(nft_staker, true);
        token::transfer_with_opt_in(creator, creator_address, token::get_collection_name(), token::get_token_name(), 0, nft_staker_address,  1);
        token_id
    }

    #[test (origin_account = @source_addr, resource_account = @nft_skaking_addr, admin = @admin_addr, creator = @0x111, nft_staker = @0x123, aptos_framework = @0x1)]
    public entry fun test_end_to_end (
        origin_account: &signer,
        resource_account: &signer,
        admin: &signer,
        creator: &signer,
        nft_staker: &signer,
        aptos_framework: &signer
    ) acquires ModuleData, UserStakeInfo {

        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        // create accounts for test
        set_up_test(origin_account, resource_account, admin, creator, nft_staker);

        let resource_account_address = signer::address_of(resource_account);
        let nft_staker_address = signer::address_of(nft_staker);

        // mint coins for the admin and deposit into protocol
        set_up_mint_coins(admin, resource_account, aptos_framework);
        deposit_funds(admin, 1000);

        assert!(coin::balance<AptosCoin>(resource_account_address) == 1000, 1);

        let token_id = setup_up_create_collection_and_token(creator, nft_staker);

        let (creator, collection, token_name, property_version) = token::get_token_id_fields(&token_id);
        assert!(collection == token::get_collection_name(), 5);
        assert!(token_name == token::get_token_name(), 6);
        assert!(property_version == 0, 7);

        let staker_balance_before = token::balance_of(nft_staker_address, token_id);
        let module_balance_before = token::balance_of(resource_account_address, token_id);

        // initial time where the user gonna stake
        timestamp::update_global_time_for_test(20000000);

        // stakes a token
        stake(nft_staker, creator, collection, token_name, 0);

        // ensure stake event is emmited
        let stake_count = event::counter(&borrow_global<UserStakeInfo>(nft_staker_address).stake_event);
        assert!(stake_count == 1, 1);

        // ensure NFT is actually staked
        let staker_balance_after = token::balance_of(nft_staker_address, token_id);
        let module_balance_after = token::balance_of(resource_account_address, token_id);

        assert!(staker_balance_after == staker_balance_before - 1, 1);
        assert!(module_balance_after == module_balance_before + 1, 1);

        // time where user gonna unstake the NFT, Its been 10 sec, so reward would be 1 coin per second,
        // so 10 coins in total
        timestamp::update_global_time_for_test(30000000);

        coin::register<AptosCoin>(nft_staker);

        // claim the staking rewards
        claimRewardsForUser(nft_staker, creator, collection, token_name, 0);
        let claim_rewards_event_count = event::counter(&borrow_global<UserStakeInfo>(nft_staker_address).claim_rewards_event);
        assert!(claim_rewards_event_count == 1, 1);

        assert!(view_pending_rewards(nft_staker_address, token_id) == 0, 1);

        // ensure user got actual reward amount according to the staking duration 
        assert!(coin::balance<AptosCoin>(nft_staker_address) == 10, 1);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 990, 1);

        // unstake the NFT, but rewards have been already claimed, so no more rewards
        unstake(nft_staker, creator, collection, token_name, 0);
        let unstake_count = event::counter(&borrow_global<UserStakeInfo>(nft_staker_address).unstake_event);
        assert!(unstake_count == 1, 1);

        // ensure the NFT has been transfered back to user
        let staker_balance_unstake = token::balance_of(nft_staker_address, token_id);
        let module_balance_unstake = token::balance_of(resource_account_address, token_id);

        assert!(staker_balance_unstake == staker_balance_before, 1);
        assert!(module_balance_unstake == module_balance_before, 1);

        // ensure rewards for user are same, coz user already claimed
        assert!(coin::balance<AptosCoin>(nft_staker_address) == 10, 1);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 990, 1);
    }

    #[test (origin_account = @source_addr, resource_account = @nft_skaking_addr, admin = @admin_addr, creator = @0x111, nft_staker = @0x123, aptos_framework = @0x1)]
    public entry fun test_admin_functions(
        origin_account: &signer,
        resource_account: &signer,
        admin: &signer,
        creator: &signer,
        nft_staker: &signer,
        aptos_framework: &signer
    ) acquires ModuleData {
        set_up_test(origin_account, resource_account, admin, creator, nft_staker);

        let resource_account_address = signer::address_of(resource_account);
        let admin_address = signer::address_of(admin);
        set_up_mint_coins(admin, resource_account, aptos_framework);

        assert!(coin::balance<AptosCoin>(admin_address) == 1000, 1);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 0, 1);

        deposit_funds(admin, 500);

        // ensure admin is able to deposit rewards coins
        assert!(coin::balance<AptosCoin>(admin_address) == 500, 1);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 500, 1);

        withdraw_funds(admin, 300);
        
        // ensure admin is able to withdraw funds
        assert!(coin::balance<AptosCoin>(admin_address) == 800, 1);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 200, 1);

        assert!(get_funds() == 200, 1);
    }

    #[test (origin_account = @source_addr, resource_account = @nft_skaking_addr, admin = @admin_addr, creator = @0x111, nft_staker = @0x123, aptos_framework = @0x1)]
    #[expected_failure]
    public entry fun test_failure_claim_for_unstaked_token(
        origin_account: &signer,
        resource_account: &signer,
        admin: &signer,
        creator: &signer,
        nft_staker: &signer,
        aptos_framework: &signer
    ) acquires ModuleData, UserStakeInfo {
        set_up_test(origin_account, resource_account, admin, creator, nft_staker);
        set_up_mint_coins(admin, resource_account, aptos_framework);

        deposit_funds(admin, 500);

        let token_id = setup_up_create_collection_and_token(creator, nft_staker);
        let (creator, collection, token_name, _property_version) = token::get_token_id_fields(&token_id);

        stake(nft_staker, creator, collection, token_name, 0);
        
        // ensure no rewards for unstaked tokens
        unstake(nft_staker, creator, collection, token_name, 0);
        claimRewardsForUser(nft_staker, creator, collection, token_name, 0);
        
    }

    #[test (origin_account = @source_addr, resource_account = @nft_skaking_addr, admin = @admin_addr, creator = @0x111, nft_staker = @0x123, aptos_framework = @0x1)]
    #[expected_failure]
    public entry fun test_failure_double_unstake(
        origin_account: &signer,
        resource_account: &signer,
        admin: &signer,
        creator: &signer,
        nft_staker: &signer,
        aptos_framework: &signer
    ) acquires ModuleData, UserStakeInfo {
        set_up_test(origin_account, resource_account, admin, creator, nft_staker);
        set_up_mint_coins(admin, resource_account, aptos_framework);

        deposit_funds(admin, 500);

        let token_id = setup_up_create_collection_and_token(creator, nft_staker);
        let (creator, collection, token_name, _property_version) = token::get_token_id_fields(&token_id);

        stake(nft_staker, creator, collection, token_name, 0);

        // ensure no double unstaking for same token
        unstake(nft_staker, creator, collection, token_name, 0);
        unstake(nft_staker, creator, collection, token_name, 0);
        
    }


    #[test (origin_account = @source_addr, resource_account = @nft_skaking_addr, admin = @admin_addr, creator = @0x111, nft_staker = @0x123, aptos_framework = @0x1)]
    #[expected_failure]
    public entry fun test_failure_double_stake(
        origin_account: &signer,
        resource_account: &signer,
        admin: &signer,
        creator: &signer,
        nft_staker: &signer,
        aptos_framework: &signer
    ) acquires ModuleData, UserStakeInfo {
        set_up_test(origin_account, resource_account, admin, creator, nft_staker);
        set_up_mint_coins(admin, resource_account, aptos_framework);

        deposit_funds(admin, 500);

        let token_id = setup_up_create_collection_and_token(creator, nft_staker);
        let (creator, collection, token_name, _property_version) = token::get_token_id_fields(&token_id);

        // ensure no double staking for same token
        stake(nft_staker, creator, collection, token_name, 0);
        stake(nft_staker, creator, collection, token_name, 0);

    }


}


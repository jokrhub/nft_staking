module nft_skaking_addr::staking {

    use aptos_std::table::{Self, Table};
    use std::string::{Self, String};
    use aptos_token::token::{Self, TokenId};
    use aptos_framework::timestamp;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::resource_account;
    use std::signer;

    struct StakeInfo has store, drop {
        pendingRewards: u256,
        startTime: u64
    }

    struct UserStakeInfo has key {
        stakes: Table<TokenId, StakeInfo>,
    }

    struct ModuleData has key {
        signer_cap: SignerCapability,
        total_reward_amount: u256
    }

    fun init_module(resource_signer: &signer) {
        // aptos move create-resource-account-and-publish-package --seed 1334 --address-name nft_staking_addr --profile default --named-addresses source_addr=552cdb8b245938e3e19303dbf77f0b900153fff2dab96f96586b0c335bb8a111
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @source_addr);
        move_to(resource_signer, ModuleData {
            signer_cap: resource_signer_cap,
            total_reward_amount: 0,
        });
    }

    public entry fun stake(account: &signer, creator: address, collection_name: String, token_name: String, token_property_version: u64) acquires ModuleData, UserStakeInfo {

        let module_data = borrow_global_mut<ModuleData>(@nft_skaking_addr);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);

        let signer_address = signer::address_of(account);
        let resource_account_address = signer::address_of(&resource_signer);

        // opt in direct transfer by resource account
        token::opt_in_direct_transfer(&resource_signer, true);  

        // transfer nft to resource account
        token::transfer_with_opt_in(account, creator, collection_name, token_name, token_property_version, resource_account_address,  1);

        let userStakeInfo = borrow_global_mut<UserStakeInfo>(signer_address);

        let token_id = token::create_token_id_raw(creator, collection_name, token_name, token_property_version);

        // transfer the nft from user to resourse account
        // create a corresponding StakeInfo for user
        let stake_info = StakeInfo {
            pendingRewards: 0, 
            startTime: timestamp::now_seconds()
        };

        // add stake_info to stakes list
        table::upsert(&mut userStakeInfo.stakes, token_id, stake_info);

    }

    public entry fun unstake(receiver: &signer, creator: address, collection_name: String, token_name: String, token_property_version: u64) acquires ModuleData, UserStakeInfo {

        let receiver_address = signer::address_of(receiver);

        let module_data = borrow_global_mut<ModuleData>(@nft_skaking_addr);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);

        let token_id = token::create_token_id_raw(creator, collection_name, token_name, token_property_version);

        let userStakeInfo = borrow_global_mut<UserStakeInfo>(receiver_address);

        table::remove(&mut userStakeInfo.stakes, token_id);

        token::opt_in_direct_transfer(receiver, true);

        token::transfer_with_opt_in(&resource_signer, creator, collection_name, token_name, token_property_version, receiver_address,  1);

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
    ): TokenId acquires Collections, TokenStore {
        use std::string;
        use std::bcs;
        let mutate_setting = collection_mutate_setting;

        create_collection(
            creator,
            get_collection_name(),
            string::utf8(b"Collection: Hello, World"),
            string::utf8(b"https://aptos.dev"),
            collection_max,
            mutate_setting
        );

        let default_keys = if (vector::length<String>(&property_keys) == 0) { vector<String>[string::utf8(b"attack"), string::utf8(b"num_of_use")] } else { property_keys };
        let default_vals = if (vector::length<vector<u8>>(&property_values) == 0) { vector<vector<u8>>[bcs::to_bytes<u64>(&10), bcs::to_bytes<u64>(&5)] } else { property_values };
        let default_types = if (vector::length<String>(&property_types) == 0) { vector<String>[string::utf8(b"u64"), string::utf8(b"u64")] } else { property_types };
        let mutate_setting = token_mutate_setting;
        create_token_script(
            creator,
            get_collection_name(),
            get_token_name(),
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
        create_token_id_raw(signer::address_of(creator), get_collection_name(), get_token_name(), 0)
    }

    #[test(staker = @0x123,  resource_account = @0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5, nft_skaking_addr = 0xcafe)]
    public entry fun test_stake(admin: signer) acquires TodoList {
        account::create_account_for_test(signer::address_of(&staker));

        init_module(&resource_account);

        let token_id = create_collection_and_token(
            &staker,
            1,
            2,
            1,
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
            vector<bool>[false, false, false],
            vector<bool>[false, false, false, false, false],
        );
        let collections = borrow_global<Collections>(signer::address_of(&staker));
        assert!(event::counter(&collections.create_collection_events) == 1, 1);

        stake(&staker, token_id.token_data_id.creator, token_id.token_data_id.collection_name, token_id.token_data_id.token_name, 0);

    }
}


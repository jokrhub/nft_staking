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
}

script {
    use std::signer;
    use std::string::{Self, String};
    use std::bcs;
    use std::vector;
    use aptos_token::token::{Self};

    fun create_collection_and_token(creator: &signer, nft_staker_address: address) {

        let amount = 1;
        let collection_max = 2;
        let token_max = 1;
        let property_keys = vector<String>[];
        let property_values = vector<vector<u8>>[];
        let property_types = vector<String>[];
        let collection_mutate_setting = vector<bool>[false, false, false];
        let token_mutate_setting = vector<bool>[false, false, false, false, false];

        token::create_collection(
            creator,
            string::utf8(b"Collection A"),
            string::utf8(b"Collection: Hello, World"),
            string::utf8(b"https://aptos.dev"),
            collection_max,
            collection_mutate_setting
        );

        let default_keys = if (vector::length<String>(&property_keys) == 0) { vector<String>[string::utf8(b"attack"), string::utf8(b"num_of_use")] } else { property_keys };
        let default_vals = if (vector::length<vector<u8>>(&property_values) == 0) { vector<vector<u8>>[bcs::to_bytes<u64>(&10), bcs::to_bytes<u64>(&5)] } else { property_values };
        let default_types = if (vector::length<String>(&property_types) == 0) { vector<String>[string::utf8(b"u64"), string::utf8(b"u64")] } else { property_types };

        token::create_token_script(
            creator,
            string::utf8(b"Collection A"),
            string::utf8(b"Token A"),
            string::utf8(b"Hello, Token"),
            amount,
            token_max,
            string::utf8(b"https://aptos.dev"),
            signer::address_of(creator),
            100,
            0,
            token_mutate_setting,
            default_keys,
            default_vals,
            default_types,
        );

        let creator_address = signer::address_of(creator);
        token::transfer_with_opt_in(creator, creator_address, string::utf8(b"Collection A"), string::utf8(b"Token A"), 0, nft_staker_address,  1);
    }
}
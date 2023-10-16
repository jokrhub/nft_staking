script {
    use std::signer;
    use aptos_token::token::{Self, TokenId};

    fun staker_opt_in_direct_transfer(nft_staker: &signer) {
        token::opt_in_direct_transfer(nft_staker, true);
    }
}
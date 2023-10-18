# NFT Staking

## Setup

Create default and admin profiles using 
```
aptos init --profile default
aptos init --profile admin
```

Replace `source_addr` and `admin_addr` using above generated addresses in `Move.toml` accordingly

## Compile
`aptos move compile --skip-fetch-latest-git-deps --skip-attribute-checks`

## Test

Change the address in `Move.toml` as mentioned below
```
admin_addr=[admin address]
source_addr='0xcafe'
nft_staking_addr='0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5'
```
`aptos move test --skip-fetch-latest-git-deps --skip-attribute-checks`

## Publish

Change the address in `Move.toml` as mentioned below
```
[addresses]
admin_addr=[admin address]
source_addr=[default address]
```
`aptos move create-resource-account-and-publish-package --seed 1234 --address-name nft_staking_addr --profile default  --skip-fetch-latest-git-deps`

Note the generated resource account.
# NFT Staking

## Setup

1. Create default and admin profiles using 
`aptos init --profile default`
`aptos init --profile admin`

2. Replace `source_addr` and `admin_addr` using above generated addresses in `Move.toml`

## Compile
`aptos move compile --skip-fetch-latest-git-deps --skip-attribute-checks`

## Test
`aptos move test --skip-fetch-latest-git-deps --skip-attribute-checks`

## Publish
`aptos move create-resource-account-and-publish-package --seed [seed] --address-name staking --profile default  --skip-fetch-latest-git-deps`
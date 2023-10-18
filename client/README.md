# Client application for NFT stking

## 1. Setup

Create default and admin profiles using 
```
aptos init --profile default
aptos init --profile admin
```

Replace `source_addr` and `admin_addr` using above generated addresses in `Move.toml` accordingly



## 2. Publish

Change the address in `Move.toml` as mentioned below
```
[addresses]
admin_addr=[admin address]
source_addr=[default address]
```
`aptos move create-resource-account-and-publish-package --seed 1234 --address-name nft_staking_addr --profile default  --skip-fetch-latest-git-deps`

Note the generated resource account.

## 3. Run client

1. Go to `client` folder
2. Update `config.tsx` file as mentioned below
```
export const MODULE_ADDRESS = [generated resource account];
export const CREATOR_PKEY = [default account private key];
export const CREATOR_ADDRESS = [default account address];
export const ADMIN_PKEY = [admin account private key];
export const ADMIN_ADDRESS = [admin account address];
```
Note: Ensure all addresses are prefixed with `0x` in `config.tsx`

3. Import `creator` and `admin` account into your wallet in browser
4. npm install
5. npm start


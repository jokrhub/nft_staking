import { Layout, Row, Col, Card, Skeleton, Empty, Button, notification } from "antd";
import { ReloadOutlined } from '@ant-design/icons';
import { WalletSelector } from "@aptos-labs/wallet-adapter-ant-design";
import "@aptos-labs/wallet-adapter-ant-design/dist/index.css";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useState, useEffect } from "react";

import { Network, Provider, AptosClient, AptosAccount, TokenClient, FaucetClient, HexString } from "aptos";
import { NODE_URL, FAUCET_URL, CREATOR_ADDRESS, CREATOR_PKEY, MODULE_ADDRESS, ADMIN_PKEY, ADMIN_ADDRESS } from "./config";

const client = new AptosClient(NODE_URL);
const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL);
const tokenClient = new TokenClient(client)

const pkey = new HexString(CREATOR_PKEY).toUint8Array();
const creator = new AptosAccount(pkey, CREATOR_ADDRESS);

const admin_pkey = new HexString(ADMIN_PKEY).toUint8Array();
const admin = new AptosAccount(admin_pkey, ADMIN_ADDRESS);

const provider = new Provider(Network.DEVNET);

type NotificationType = 'success' | 'error';
type Action = 'stake' | 'unstake' | 'claimRewardsForToken' | 'updateRewards';

function App() {

  const { account, signAndSubmitTransaction, signTransaction } = useWallet();
  const [stakesLoader, setStakesLoader] = useState(true);
  const [tokensLoader, setTokensLoader] = useState(true);
  const [userStakes, setUserStakes] = useState<any[]>([]);
  const [userTokens, setUserTokens] = useState([]);
  const [showError, setIsError] = useState()

  const [api, contextHolder] = notification.useNotification();

  console.log("Moduele address:", MODULE_ADDRESS);
  console.log("Admin address:", ADMIN_ADDRESS);
  console.log("Creator address:", CREATOR_ADDRESS);
  console.log("Current address:", account?.address);

  useEffect(() => {
    if (account?.address) {
      setup();
      depositFunds();
      fetchUserTokens();
      fetchUserStakes();
    }
  }, [account?.address]);

  const openNotification = (type: NotificationType, message: string, description: string | undefined) => {
    api[type]({
      message: message,
      description: description,
      duration: 4,
      placement: "topLeft"
    });
  };

  const setup = async () => {

    try {
      await faucetClient.fundAccount(creator.address(), 100_000_000_000);
      await faucetClient.fundAccount(MODULE_ADDRESS, 100_000_000_000);
      await faucetClient.fundAccount(admin.address(), 100_000_000_000);
    } catch (e: any) {
      console.log("Limit exeeded: ", e)
    }

    
    if (account?.address != CREATOR_ADDRESS) return

    const collectionName = `Collection ${(Math.random() + 1).toString(36).substring(7)}`;
    const tokenName = `Token ${(Math.random() + 1).toString(36).substring(7)}`;

    try {

      const txnHash1 = await tokenClient.createCollection(
        creator,
        collectionName,
        "creator's simple collection",
        "https://creator.com",
      );
      await client.waitForTransaction(txnHash1, { checkSuccess: true });

      const txnHash2 = await tokenClient.createToken(
        creator,
        collectionName,
        tokenName,
        "creator's simple token",
        1,
        "https://aptos.dev/img/nyan.jpeg",
      );
      await client.waitForTransaction(txnHash2, { checkSuccess: true });

      openNotification('success', "Setup succesfull. Created collection and tokens", "");

    } catch (e: any) {
      console.log("Error in setup: ", e)
      openNotification('error', "Error in setup", "Please change the collection and token names in config");

    } finally {
      fetchUserTokens();
    }

  }

  const depositFunds = async () => {

    if (account?.address != ADMIN_ADDRESS) return
    try {
      const payload = {
        type: "entry_function_payload",
        function: `${MODULE_ADDRESS}::staking::deposit_funds`,
        type_arguments: [],
        arguments: [100_000_000],
      };
      const txnHash3 = await signAndSubmitTransaction(payload);
      console.log("resonse:", txnHash3)
      openNotification("success", "Deposit successfull", "");
    } catch (e: any) {
      console.log("Error in deposit: ", e)
    }
  }

  const fetchUserTokens = async () => {
    if (!account) return [];
    if (account?.address != CREATOR_ADDRESS) return;

    try {
      const userNfts: any = []
      const nft_list = (await provider.getAccountNFTs(creator.address().hex())).current_token_ownerships;

      nft_list.forEach(nft => {
        userNfts.push({
          creator: nft.current_token_data?.creator_address,
          collection: nft.current_token_data?.collection_name,
          name: nft.current_token_data?.name,
          property_version: nft.property_version,
        })
      })
      console.log("user tokes : ", userNfts);
      setUserTokens(userNfts);
    } catch (e: any) {
      console.log("error", e)
      openNotification("success", "No token available", "");
    } finally {
      setTokensLoader(false);
    }

  }

  const fetchUserStakes = async () => {
    if (!account) return [];
    if (account?.address != CREATOR_ADDRESS) return;

    try {
      const UserStakeInfoResource = await provider.getAccountResource(
        account?.address,
        `${MODULE_ADDRESS}::staking::UserStakeInfo`
      );

      const tableHandle = (UserStakeInfoResource as any).data.stakes.handle;
      const stake_keys: [] = (UserStakeInfoResource as any).data.stake_keys;

      let stakes: any = [];

      for (let index = 0; index <= stake_keys.length - 1; index++) {
        const tokenId: any = stake_keys[index];
        const tableItem = {
          key_type: "0x3::token::TokenId",
          value_type: `${MODULE_ADDRESS}::staking::StakeInfo`,
          key: tokenId
        };
        const stake: any = await provider.getTableItem(tableHandle, tableItem);
        stake['creator'] = tokenId.token_data_id?.creator;
        stake['collection'] = tokenId.token_data_id?.collection;
        stake['name'] = tokenId.token_data_id?.name;
        stake['property_version'] = tokenId.property_version;

        stakes.push(stake);

        console.log("stake: ", stake)
      }

      setUserStakes(stakes);
      console.log("user stakes: ", stakes)

    } catch (e: any) {
      console.log("error", e)
      openNotification("success", "No stakes available", "");
    } finally {
      setStakesLoader(false)
    }

  }

  const performAction = async (action: Action, creator: string | undefined, collection_name: string, token_name: string, token_property_version: number) => {
    if (!account) return;

    const payload = {
      type: "entry_function_payload",
      function: `${MODULE_ADDRESS}::staking::${action}`,
      type_arguments: [],
      arguments: [creator, collection_name, token_name, token_property_version],
    };

    try {
      // sign and submit transaction to chain
      const response = await signAndSubmitTransaction(payload);
      // wait for transaction
      await provider.waitForTransaction(response.hash);

      if (action == 'stake')
        openNotification("success", "Stake successfull", "");
      else if (action == 'unstake')
        openNotification("success", "Unstake successfull", "");
      else if (action == 'claimRewardsForToken')
        openNotification("success", "Rewards claimed successfully", "");
      else if (action == 'updateRewards')
        openNotification("success", "Rewards updated successfully", "");

    } catch (error: any) {
      console.log("error", error);

      if (action == 'stake')
        openNotification("success", "Error in staking token", "")
      else if (action == 'unstake')
        openNotification("error", "Error while unstaking token.", "No funds in contract to unstake. Please select admin wallet to deposit funds");
      else if (action == 'claimRewardsForToken')
        openNotification("error", "Error while claiming rewards.", "No funds in contract to unstake. Please select admin wallet to deposit funds");
      else if (action == 'updateRewards')
        openNotification("error", "Error in updating rewards", "");
    } finally {
      fetchUserTokens();
      fetchUserStakes();
    }
  }

  return (
    <>
      {contextHolder}
      <Layout style={{marginBottom: "100px"}}>
        <Row align="middle" style={{ margin: "0px 20px" }} gutter={[32, 32]}>
          <Col span={7}>
            <h1>NFT staking</h1>
          </Col>
          <Col span={5} style={{ textAlign: "right" }}>
            <h3>{account?.address == ADMIN_ADDRESS ? "ADMIN" : "STAKER"}</h3>
          </Col>
          <Col span={12} style={{ textAlign: "right" }}>
            <WalletSelector />
          </Col>
        </Row>
      </Layout>

      <Row gutter={[32,32]} style={{margin:'30px'}}>
        <Col span={12}>
          <Row gutter={[32,32]} style={{margin:'100px', padding: "50px", backgroundColor: "#f5f5f5", borderRadius: "10px", height: "80vh", overflow: "auto"}}>
            <Col span={24}>
              <h1> Collection</h1>
            </Col>
            {
              tokensLoader ?
                [1, 2, 3, 4, 5, 6].map(() => (
                  <Col sm={24} md={12}>
                    <Card>
                      <Skeleton active />
                    </Card>
                  </Col>
                ))
                :
                userTokens.length == 0 ? <Empty /> : userTokens.map((nft: any) => (
                  <Col sm={24} md={11}>
                    <Card title="NFT" bordered={true}
                      actions={[
                        <div onClick={async () => { await performAction('stake', nft.creator, nft.collection, nft.name, nft.property_version) }}> Stake </div>
                      ]}
                    >
                      <p>{nft.name}</p>
                      <p>{nft.collection}</p>

                    </Card>
                  </Col>
                ))
            }
          </Row>
        </Col>

        <Col span={12}>
          <Row gutter={[32,32]} style={{margin:'100px', padding: "50px", backgroundColor: "#f5f5f5", borderRadius: "10px",  height: "80vh", overflow: "auto"}}>
            <Col span={24}>
              <h1> Staked tokens</h1>
            </Col>
            {
              stakesLoader ?
                [1, 2, 3, 4, 5, 6].map(() => (
                  <Col sm={24} md={12}>
                    <Card>
                      <Skeleton active />
                    </Card>
                  </Col>
                ))
                :
                userStakes.length == 0 ? <Empty /> : userStakes.map((nft: any) => (
                  <Col sm={24} md={11}>
                    <Card title="Stake Info" bordered={true}
                      actions={[
                        <div onClick={async () => { await performAction('unstake', nft.creator, nft.collection, nft.name, nft.property_version) }}> Unstake </div>,
                        <div onClick={async () => { await performAction('claimRewardsForToken', nft.creator, nft.collection, nft.name, nft.property_version) }}> Claim </div>
                      ]}
                      extra={
                        <Button type="link" onClick={async () => { await performAction('updateRewards', nft.creator, nft.collection, nft.name, nft.property_version) }}>
                          <ReloadOutlined />
                        </Button>
                      }
                    >
                      <p>{nft.name}</p>
                      <p>{nft.collection}</p>
                      <p>Rewards: {nft.pendingRewards}</p>

                    </Card>
                  </Col>
                ))
            }
          </Row>
        </Col>
      </Row>
    </>
  );
}

export default App;

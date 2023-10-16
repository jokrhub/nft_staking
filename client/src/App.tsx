import { Layout, Row, Col, Button, Card, Spin, Skeleton} from "antd";
import { WalletSelector } from "@aptos-labs/wallet-adapter-ant-design";
import "@aptos-labs/wallet-adapter-ant-design/dist/index.css";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useState, useEffect } from "react";
import { Network, Provider, AptosClient, AptosAccount, TokenClient, FaucetClient, CoinClient } from "aptos";

const NODE_URL = "https://fullnode.devnet.aptoslabs.com";
const FAUCET_URL = "https://faucet.devnet.aptoslabs.com";

const client = new AptosClient(NODE_URL);
const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL);
const tokenClient = new TokenClient(client)

type TokenId = {
  token_data_id: any,
  property_version: number
}


function App() {

  const MODULE_ADDRESS = "0xcafe";

  const { account } = useWallet();
  const provider = new Provider(Network.DEVNET);

  const [hasStakes, setHasStakes] = useState(false);
  const [stakes, setStakes] = useState([]);
  const [userTokens, setUserTokens] = useState([]);
  const [loader, setLoader] = useState(false);

  const client = new AptosClient(NODE_URL);
  const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL);

  const tokenClient = new TokenClient(client);
  const coinClient = new CoinClient(client);

  const creator = new AptosAccount();
  const nft_staker = new AptosAccount();

  useEffect(() => {
    setLoader(true);
    if (account?.address) {
      setup();
      fetchStakes();
    }
  }, [account?.address]);

  const setup = async () => {

    await faucetClient.fundAccount(creator.address(), 100_000_000);
    await faucetClient.fundAccount(nft_staker.address(), 100_000_000);

    const collectionName = "creator's";
    const tokenName = "creator's first token";
    const tokenPropertyVersion = 0;

    const tokenId = {
      token_data_id: {
        creator: creator.address().hex(),
        collection: collectionName,
        name: tokenName,
      },
      property_version: `${tokenPropertyVersion}`,
    };

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

    const aliceBalance1 = await tokenClient.getToken(
      creator.address(),
      collectionName,
      tokenName,
      `${tokenPropertyVersion}`,
    );

    const userNfts: any = []
    const nft_list = (await provider.getAccountNFTs(creator.address().hex())).current_token_ownerships;
    console.log(nft_list);

    nft_list.forEach(nft => {
      userNfts.push({
        token_data_id: {
          creator: nft.current_token_data?.creator_address,
          collection: nft.current_token_data?.collection_name,
          name: nft.current_token_data?.name,
        },
        property_version: nft.property_version,
      })
    })

    setUserTokens(userNfts);
    setLoader(false);

  }

  const fetchUserTokens = async () => {

    if (!account) return [];
    
  }

  const stakeNft = async (creator: string, collection_name: string, token_name: string, token_property_version: number) => {

  }

  const fetchStakes = async () => {
    if (!account) return [];
    try {
      const UserStakeInfoResource = await provider.getAccountResource(
        account?.address,
        `${MODULE_ADDRESS}::staking::UserStakeInfo`
      );
      setHasStakes(true);

      const tableHandle = (UserStakeInfoResource as any).data.stakes.handle;
      const stake_keys: [] = (UserStakeInfoResource as any).data.stake_keys;

      let stakes = [];

      for (let index = 1; index <= stake_keys.length; index++) {
        const tableItem = {
          key_type: "0x3::token::TokenId",
          value_type: `${MODULE_ADDRESS}::todolist::Task`,
          key: stake_keys[index]
        };
        const stake = await provider.getTableItem(tableHandle, tableItem);
        stakes.push(stake);
      }

      console.log("staked", stakes)

    } catch (e: any) {
      setHasStakes(false);
    }
  }

  return (
    <> 
      <Layout>
        <Row align="middle">
          <Col span={10} offset={2}>
            <h1>NFT staking</h1>
          </Col>
          <Col span={12} style={{ textAlign: "right", paddingRight: "200px" }}>
            <WalletSelector />
          </Col>
        </Row>
      </Layout>

      <Row justify="center" gutter={[40, 40]} style={{ margin: "5rem 30rem" }}>
        <Col span={4}>
          <h1> Collection</h1>
        </Col>
      </Row>

    
      <Row justify="center" gutter={[40, 40]} style={{ margin: "5rem 30rem" }}>
        {
          loader ? 
          [1,2,3].map(()=>(
            <Col sm={24} md={12} lg={8}>
              <Card>
                <Skeleton active />
              </Card>
            </Col>
          ))
          :
          userTokens.map((nft: any) => (
            <Col sm={24} md={12} lg={8}>
              <Card title="Card title" bordered={true}
                actions={[
                  <> Claim Rewards </>,
                  <>Unstake</>
                ]}
              >
                <p>{nft.token_data_id.name}</p>
                <p>{nft.token_data_id.collection}</p>

              </Card>
            </Col>
          ))
        }
      </Row>

      <Row justify={"center"} gutter={[0, 32]} style={{ marginTop: "5rem" }}>
        <Col span={4}>
          <Button
            block
            type="primary"
            style={{ height: "40px", backgroundColor: "#3f67ff" }}
          >
            Stake NFT
          </Button>
        </Col>
      </Row>
        
    </>
  );
}

export default App;

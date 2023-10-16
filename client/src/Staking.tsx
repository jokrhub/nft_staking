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

const Staking =()=>{

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
    
    return (
        <>
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
      </Row> ̰
        </>
    )
}
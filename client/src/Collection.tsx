
import { Row, Col, Card, Skeleton} from "antd";

const Collection = (userTokens: any,  tokensLoader: Boolean, stakeNft: any) => {
    console.log("tokens loader: ", tokensLoader)
    return (
        <Row justify="center" gutter={[40, 40]} style={{ margin: "5rem 30rem" }}>
        {
            tokensLoader ? 
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
                    <div onClick={async () => {await stakeNft(nft.creator, nft.collection, nft.name, nft.property_version)}}> Stake </div>
                ]}
                >
                <p>{nft.name}</p>
                <p>{nft.collection}</p>

                </Card>
            </Col>
            ))
        }
        </Row>
    )
}

export default Collection;
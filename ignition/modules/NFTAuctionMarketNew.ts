import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const NFTAuctionMarketModule = buildModule(
  "NFTAuctionMarketNewModule",
  (m) => {
    // ----------------------------
    // 1. 参数：NFT 合约地址 + Chainlink 预言机地址
    // ----------------------------
    const nftAddress = m.getParameter(
      "nftAddress",
      "0x65e3407ac8d124e8838E7346954048F36B4C0BA3" // Sepolia NFT
    );

    const priceFeedAddress = m.getParameter(
      "priceFeedAddress",
      "0x694AA1769357215DE4FAC081bf1f309aDC325306" // Sepolia ETH/USD
    );

    // ----------------------------
    // 2. 部署逻辑合约 NFTAuctionMarketNew
    // ----------------------------
    const implementation = m.contract("NFTAuctionMarketNew");

    // ----------------------------
    // 3. 编码 initialize 调用
    // ----------------------------
    const initData = m.encodeFunctionCall(
      implementation,
      "initialize",
      [nftAddress, priceFeedAddress]
    );

    // ----------------------------
    // 4. 部署手写 UUPS Proxy
    // ----------------------------
    const proxy = m.contract("UUPSProxyDelegatecall", [
      implementation,
      initData,
    ]);

    // ----------------------------
    // 5. 返回 Proxy 作为主要交互对象
    // ----------------------------
    return {
      implementation,
      proxy,
    };
  }
);

export default NFTAuctionMarketModule;

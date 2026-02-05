import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ProxyModule = buildModule("NFTAuctionProxyModule", (m) => {

  const nftAddress = m.getParameter("nftAddress", "0x65e3407ac8d124e8838E7346954048F36B4C0BA3");
  const priceFeedAddress = m.getParameter("priceFeedAddress", "0x694AA1769357215DE4FAC081bf1f309aDC325306");

  const owner = m.getAccount(0);

  // ⭐ 部署 ProxyAdmin
  const proxyAdmin = m.contract("ProxyAdmin", [owner]);

  // ⭐ 部署 V1 implementation
  const implementation = m.contract("NFTAuctionMarketV1");

  const initData = m.encodeFunctionCall(
    implementation,
    "initialize",
    [owner, nftAddress, priceFeedAddress]
  );

  // ⭐ 部署 Proxy
  const proxy = m.contract("TransparentUpgradeableProxy", [
    implementation,
    proxyAdmin,
    initData
  ]);

  return { proxyAdmin, proxy };
});

const metaNFTAuctionModule = buildModule("MyNFTAuctionModule", (m) => {
  const { proxy, proxyAdmin } = m.useModule(ProxyModule);

  const auction = m.contractAt("NFTAuctionMarketV1", proxy);

  return { auction, proxy, proxyAdmin };
});

export default metaNFTAuctionModule;

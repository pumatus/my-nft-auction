import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MyNFTModuleV1", (m) => {
  const nft = m.contract("NFTAuctionMarketV1");

  return { nft };
});
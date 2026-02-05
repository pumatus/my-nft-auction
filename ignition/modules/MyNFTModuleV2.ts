import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MyNFTModuleV2", (m) => {
  const nft = m.contract("NFTAuctionMarketV2");

  return { nft };
});
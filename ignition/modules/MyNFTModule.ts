import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MyNFTModule", (m) => {
  const nft = m.contract("MyNFT");

  return { nft };
});
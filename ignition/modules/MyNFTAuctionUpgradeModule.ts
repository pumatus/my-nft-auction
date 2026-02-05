import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import MetaNFTAuctionModule from "./MyNFTAuctionProxyModule.js";

const metaNFTAuctionUpgradeModule = buildModule(
  "MyNFTAuctionUpgradeModule",
  (m) => {
    const proxyAdminOwner = m.getAccount(0);

    const { proxyAdmin, proxy } = m.useModule(MetaNFTAuctionModule);

    const auctionV2 = m.contract("NFTAuctionMarketV2");

    m.call(proxyAdmin, "upgradeAndCall", [proxy, auctionV2,"0x"], {
      from: proxyAdminOwner,
    });

    const auction = m.contractAt("NFTAuctionMarketV2", proxy, {
      id: "MyNFTAuctionV2AtProxy",
    });

    return { auction, proxyAdmin, proxy };
  },
);

export default metaNFTAuctionUpgradeModule;
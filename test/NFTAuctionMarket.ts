// import { expect } from "chai";
// import hre from "hardhat";

// describe("NFT 拍卖市场功能测试", function () {
//   let market: any;
//   let nft: any;
//   let deployer: any;

//   beforeEach(async function () {
//     // 使用 as any 避开 TypeScript 对 hre 扩展属性的检查
//     const { ethers, deployments } = hre as any; 

//     // 运行部署脚本
//     await deployments.fixture(["NFTMarket"]);

//     // 获取合约
//     const marketDeployment = await deployments.get("NFTAuctionMarket");
//     const nftDeployment = await deployments.get("MyNFT");

//     [deployer] = await ethers.getSigners();
//     market = await ethers.getContractAt("NFTAuctionMarket", marketDeployment.address);
//     nft = await ethers.getContractAt("MyNFT", nftDeployment.address);
//   });

//   it("应该能正常运行", async function () {
//     expect(market.target).to.properAddress;
//   });
// });
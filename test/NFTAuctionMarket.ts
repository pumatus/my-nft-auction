import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("NFTAuctionMarket UUPS 手写代理测试", function () {
    let market: any;
    let nft: any;
    let mockPriceFeed: any;
    let owner: any;
    let seller: any;
    let bidder1: any;
    let bidder2: any;
    
    const TOKEN_ID = 0;
    const MIN_PRICE = ethers.parseEther("1"); // 1 ETH

    beforeEach(async function () {
        // 获取签名者
        [owner, seller, bidder1, bidder2] = await ethers.getSigners();

        // 1. 部署 NFT
        const MyNFT = await ethers.getContractFactory("MyNFT");
        nft = await MyNFT.deploy();
        await nft.waitForDeployment();
        const nftAddr = await nft.getAddress();

        // 2. 部署 Mock 预言机 (8位小数, 2000 USD/ETH)
        const MockFeed = await ethers.getContractFactory("MockV3Aggregator");
        mockPriceFeed = await MockFeed.deploy(8, 200000000000n);
        await mockPriceFeed.waitForDeployment();
        const priceFeedAddr = await mockPriceFeed.getAddress();

        // 3. 部署逻辑合约 (Implementation)
        const MarketFactory = await ethers.getContractFactory("NFTAuctionMarketNew");
        const impl = await MarketFactory.deploy();
        await impl.waitForDeployment();
        const implAddr = await impl.getAddress();

        // 4. 准备初始化数据 (编码 initialize 函数调用)
        const initData = MarketFactory.interface.encodeFunctionData(
            "initialize",
            [nftAddr, priceFeedAddr]
        );

        // 5. 部署代理合约 (Proxy)
        const ProxyFactory = await ethers.getContractFactory("UUPSProxyDelegatecall");
        const proxy = await ProxyFactory.deploy(implAddr, initData);// 代理合约指向实现逻辑的合约
        await proxy.waitForDeployment();
        const proxyAddr = await proxy.getAddress();

        // 6. 重要：将逻辑合约 ABI 绑定到代理地址
        // 这样我们调用 market.createAuction 实际上是向 proxy 发送 data
        market = MarketFactory.attach(proxyAddr);

        // 7. 准备测试数据：铸造并授权
        await nft.mint(seller.address); 
        // 卖家必须授权给代理地址 (proxyAddr)，因为 delegatecall 环境下代理才是转账主体
        await nft.connect(seller).approve(proxyAddr, TOKEN_ID);
    });

    describe("createAuction", function () {
        it("应该能够成功转移 NFT 并创建拍卖", async function () {
            // 使用 seller 身份调用
            await expect(market.connect(seller).createAuction(TOKEN_ID, MIN_PRICE))
                .to.emit(market, "AuctionCreated")
                .withArgs(TOKEN_ID, MIN_PRICE);

            // 检查 NFT 是否已质押在代理合约中
            expect(await nft.ownerOf(TOKEN_ID)).to.equal(await market.getAddress());
            
            const auction = await market.auctions(TOKEN_ID);
            expect(auction.seller).to.equal(seller.address);
            expect(auction.active).to.be.true;
        });
    });

    describe("placeBid", function () {
        beforeEach(async function () {
            await market.connect(seller).createAuction(TOKEN_ID, MIN_PRICE);
        });

        it("出价低于起拍价应该失败", async function () {
            await expect(
                market.connect(bidder1).placeBid(TOKEN_ID, { value: ethers.parseEther("0.5") })
            ).to.be.revertedWith("Bid to low");
        });

        it("新出价应该退还前一个出价者", async function () {
            const bid1 = ethers.parseEther("1.5");
            const bid2 = ethers.parseEther("2.0");

            // Bidder1 先出价
            await market.connect(bidder1).placeBid(TOKEN_ID, { value: bid1 });
            const balanceBefore = await ethers.provider.getBalance(bidder1.address);
            
            // Bidder2 出更高价
            await market.connect(bidder2).placeBid(TOKEN_ID, { value: bid2 });

            // 检查 Bidder1 是否收到退款
            const balanceAfter = await ethers.provider.getBalance(bidder1.address);
            expect(balanceAfter).to.be.equal(balanceBefore + bid1);

            const auction = await market.auctions(TOKEN_ID);
            expect(auction.highestBidder).to.equal(bidder2.address);
            expect(auction.highestBid).to.equal(bid2);
        });
    });

    describe("Oracle - Chainlink Integration", function () {
        it("应该正确计算出价的美元价值", async function () {
            const bidAmount = ethers.parseEther("2"); // 2 ETH
            await market.connect(seller).createAuction(TOKEN_ID, MIN_PRICE);
            await market.connect(bidder1).placeBid(TOKEN_ID, { value: bidAmount });

            // 预言机价格 2000 USD/ETH. 2 ETH = 4000 USD
            const valInUsd = await market.getHighestBidInUsd(TOKEN_ID);
            // 结果应该是 4000 后面跟 18 个 0 (因为 ETH 精度)
            expect(valInUsd).to.equal(ethers.parseUnits("4000", 18)); 
        });
    });

    describe("settleAuction", function () {
        it("结算后卖家应收到款项，获胜者应收到 NFT", async function () {
            const bidAmount = ethers.parseEther("2");
            await market.connect(seller).createAuction(TOKEN_ID, MIN_PRICE);
            await market.connect(bidder1).placeBid(TOKEN_ID, { value: bidAmount });

            const sellerBalanceBefore = await ethers.provider.getBalance(seller.address);
            
            // 任何人执行结算
            await market.settleAuction(TOKEN_ID);

            // 检查卖家余额
            const sellerBalanceAfter = await ethers.provider.getBalance(seller.address);
            expect(sellerBalanceAfter).to.be.equal(sellerBalanceBefore + bidAmount);

            // 检查 NFT 归属
            expect(await nft.ownerOf(TOKEN_ID)).to.equal(bidder1.address);
        });
    });
});
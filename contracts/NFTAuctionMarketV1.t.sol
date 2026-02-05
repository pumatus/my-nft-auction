// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {MyNFT} from "./MyNFT.sol";
import {NFTAuctionMarketV1} from "./NFTAuctionMarketV1.sol";
import {NFTAuctionMarketV2} from "./NFTAuctionMarketV2.sol";
import {MockV3Aggregator} from "./MockV3Aggregator.sol";

contract NFTAuctionMarketV1Test is Test {
    address owner = address(1);
    address bidder1 = address(2);
    address bidder2 = address(3);
    address admin = address(4); // 单独的代理管理员

    MyNFT nft;
    NFTAuctionMarketV1 impl;
    NFTAuctionMarketV2 implV2;
    NFTAuctionMarketV1 auction; // proxy 绑定后的接口

    uint256 constant TOKEN_ID = 0;

    MockV3Aggregator mockV3Aggregator;

    function setUp() public {
        vm.deal(owner, 100 ether);
        vm.deal(bidder1, 100 ether);
        vm.deal(bidder2, 100 ether);

        // 创建 Mock Price Feed（假设 1 ETH = 2000 USD）
        mockV3Aggregator = new MockV3Aggregator(8, 2000 * 1e8); // Chainlink 价格 feed 通常是 8 位小数

        vm.startPrank(owner);
        nft = new MyNFT();
        nft.mint(owner);
        vm.stopPrank();

        impl = new NFTAuctionMarketV1();

        bytes memory initData = abi.encodeWithSelector(
            NFTAuctionMarketV1.initialize.selector,
            owner,
            address(nft),
            // address(0) // 测试中不需要真实 priceFeed
            address(mockV3Aggregator) // 使用模拟价格
        );

        // owner 代理管理员
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), admin, initData);

        auction = NFTAuctionMarketV1(address(proxy));

        // 授权 NFT 给拍卖合约
        vm.prank(owner);
        nft.approve(address(auction), TOKEN_ID);
    }

    function testCreateAuction() public {
        vm.prank(owner);
        auction.createAuction(TOKEN_ID, 1 ether);

        (address seller, uint256 tokenId, uint256 minPrice, uint256 highestBid, address highestBidder, bool active) =
            auction.auctions(TOKEN_ID);

        // 是否等于这个id的拍卖属性
        assertEq(seller, owner);
        assertEq(tokenId, TOKEN_ID);
        assertEq(minPrice, 1 ether);
        assertEq(highestBid, 0);
        assertEq(highestBidder, address(0));
        assertTrue(active);

        // NFT 已转入合约
        assertEq(nft.ownerOf(TOKEN_ID), address(auction));
    }

    function testPlaceBid() public {
        vm.prank(owner);
        auction.createAuction(TOKEN_ID, 1 ether);

        vm.prank(bidder1);
        auction.placeBid{value: 2 ether}(TOKEN_ID);

        (,,, uint256 highestBid, address highestBidder,) = auction.auctions(TOKEN_ID);

        assertEq(highestBid, 2 ether); // 出价是否等于
        assertEq(highestBidder, bidder1); // 出价者是否相同
    }

    function testRefundPreviousBidder() public {
        vm.prank(owner);
        auction.createAuction(TOKEN_ID, 1 ether);

        vm.prank(bidder1);
        auction.placeBid{value: 2 ether}(TOKEN_ID);

        uint256 bidder1BalanceBefore = bidder1.balance;

        vm.prank(bidder2);
        auction.placeBid{value: 3 ether}(TOKEN_ID);

        // bidder1 被退款
        assertEq(bidder1.balance, bidder1BalanceBefore + 2 ether);
    }

    function testSettleAuction() public {
        vm.prank(owner);
        auction.createAuction(TOKEN_ID, 1 ether);

        vm.prank(bidder1);
        auction.placeBid{value: 2 ether}(TOKEN_ID);

        uint256 sellerBalanceBefore = owner.balance;

        vm.prank(owner);
        auction.settleAuction(TOKEN_ID);

        // NFT 转移给赢家
        assertEq(nft.ownerOf(TOKEN_ID), bidder1);

        // 卖家收到 ETH
        assertEq(owner.balance, sellerBalanceBefore + 2 ether);

        // 拍卖关闭
        (,,,,, bool active) = auction.auctions(TOKEN_ID);
        assertFalse(active);
    }
}

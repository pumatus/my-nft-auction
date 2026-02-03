// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NFTAuctionMarket is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    struct Auction {
        address seller;
        uint256 tokenId;
        uint256 minPriceEth; // 最低起拍价格
        uint256 highestBid;
        address highestBidder;
        bool active;
    }

    mapping(uint256 => Auction) public auctions;
    IERC721 public nftConntract;
    AggregatorV3Interface internal ethUsdFeed;

    event AuctionCreated(uint256 tokenId, uint256 minPriceEth);
    event BidPlaced(uint256 tokenId, address bidder, uint256 amount);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _nftAddress, address _priceFeedAddress) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        nftConntract = IERC721(_nftAddress);
        ethUsdFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    // 创建拍卖
    function createAuction(uint256 _tokenId, uint256 _minPriceEth) external {
        nftConntract.transferFrom(msg.sender, address(this), _tokenId);
        auctions[_tokenId] = Auction({
            seller: msg.sender,
            tokenId: _tokenId,
            minPriceEth: _minPriceEth,
            highestBid: 0,
            highestBidder: address(0),
            active: true
        });
        emit AuctionCreated(_tokenId, _minPriceEth);
    }

    // 出价
    function placeBid(uint256 _tokenId) external payable {
        Auction storage auction = auctions[_tokenId];
        require(auction.active, "Auction not active");
        require(msg.value > auction.minPriceEth && msg.value > auction.highestBid, "Bid to low");

        // 退还前一个出价者
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
        emit BidPlaced(_tokenId, msg.sender, msg.value); // 发送拍卖事件
    }

    // 使用 Chainlink 获取当前最高出价的美元价值
    function getHighestBidInUsd(uint256 _tokenId) public view returns (uint256) {
        (, int256 price,,,) = ethUsdFeed.latestRoundData();
        uint256 ethPrice = uint256(price * 1e10); // 转换18位小数
        return (auctions[_tokenId].highestBid * ethPrice); // 1e18
    }

    // UUPS 升级权限检查
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

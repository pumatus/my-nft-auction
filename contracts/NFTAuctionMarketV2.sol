// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NFTAuctionMarketV2 is Initializable {
    address public owner;

    struct Auction {
        address seller;
        uint256 tokenId;
        uint256 minPriceEth;
        uint256 highestBid;
        address highestBidder;
        bool active;
    }

    mapping(uint256 => Auction) public auctions;
    IERC721 public nftConntract;
    AggregatorV3Interface internal ethUsdFeed;

    event AuctionCreated(uint256 indexed tokenId, uint256 minPriceEth);
    event BidPlaced(uint256 indexed tokenId, address bidder, uint256 amount);
    event AuctionSettled(uint256 indexed tokenId, address winner, uint256 amount);

    // 仅 owner 修饰器
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    uint256 private _status; // 重入锁
    modifier nonReentrant() {
        require(_status != 1, "ReentrancyGuard: reentrant call");
        _status = 1;
        _;
        _status = 2;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _nftAddress, address _priceFeedAddress) external initializer {
        require(_owner != address(0), "invalid");
        owner = _owner;
        _status = 2; // 初始化重入锁状态

        nftConntract = IERC721(_nftAddress);
        ethUsdFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    function createAuction(uint256 _tokenId, uint256 _minPriceEth) external onlyOwner {
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

    function placeBid(uint256 _tokenId) external payable nonReentrant {
        Auction storage auction = auctions[_tokenId];
        require(auction.active, "Auction not active");
        require(msg.value > auction.minPriceEth && msg.value > auction.highestBid, "Bid to low");

        address pBidder = auction.highestBidder;
        uint256 pBid = auction.highestBid;

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        if (pBidder != address(0)) {
            (bool success,) = pBidder.call{value: pBid}("");
            require(success, "refund failed");
        }
        emit BidPlaced(_tokenId, msg.sender, msg.value);
    }

    function getHighestBidInUsd(uint256 _tokenId) public view returns (uint256 usdAmount, uint256 fee) {
        (, int256 price,,,) = ethUsdFeed.latestRoundData();

        uint256 ethPrice = uint256(price * 1e10);

        usdAmount = (auctions[_tokenId].highestBid * ethPrice) / 1e18;

        // 动态手续费
        if (usdAmount < 1000 ether) {
            fee = auctions[_tokenId].highestBid * 3 / 100;
        } else if (usdAmount < 5000 ether) {
            fee = auctions[_tokenId].highestBid * 2 / 100;
        } else {
            fee = auctions[_tokenId].highestBid * 1 / 100;
        }
    }

    function settleAuction(uint256 _tokenId) external nonReentrant {
        Auction storage auction = auctions[_tokenId];
        require(auction.active, "Already settled");
        require(auction.highestBidder != address(0), "No winner!");

        auction.active = false;

        (bool sellerSuccess,) = auction.seller.call{value: auction.highestBid}("");
        require(sellerSuccess, "seller payment failed");

        // safeTransferFrom可以判断地址是否可以接受，否则回滚
        nftConntract.safeTransferFrom(address(this), auction.highestBidder, _tokenId);

        emit AuctionSettled(_tokenId, auction.highestBidder, auction.highestBid);
    }
}

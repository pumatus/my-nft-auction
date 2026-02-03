// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// 可升级合约库文件
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// chainlink预言机
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// 使用UUPS 代理模式，集成预言机
contract NFTAuctionMarket is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    struct Auction {
        // 拍卖结构体
        address seller; // 卖家地址
        uint256 tokenId; // token ID
        uint256 minPriceEth; // 最低起拍价格
        uint256 highestBid; // 当前最高出价
        address highestBidder; // 当前最高出价者的地址
        bool active; // 拍卖状态 true 进行中 false 已结束
    }

    // evm 状态变量
    mapping(uint256 => Auction) public auctions; // token ID对拍卖信息的映射
    IERC721 public nftConntract; // NFT 合约
    AggregatorV3Interface internal ethUsdFeed; // Chainlink ETH/USD 价格喂送接口

    // 拍卖事件 topic (indexed)
    event AuctionCreated(uint256 indexed tokenId, uint256 minPriceEth);
    // 出价事件
    event BidPlaced(uint256 indexed tokenId, address bidder, uint256 amount);
    // 结束事件
    event AuctionSettled(uint256 indexed tokenId, address winner, uint256 amount);

    constructor() {
        // 锁定实现合约，防止他人直接调用实现合约的初始化
        _disableInitializers();
    }

    // 代理模式中需要替代构造函数
    function initialize(address _nftAddress, address _priceFeedAddress) public initializer {
        __Ownable_init(); // 初始化所有权模块
        __UUPSUpgradeable_init(); // 初始化 UUPS 升级模块
        nftConntract = IERC721(_nftAddress); // nft 合约地址
        ethUsdFeed = AggregatorV3Interface(_priceFeedAddress); // 价格地址
    }

    // 创建拍卖
    function createAuction(uint256 _tokenId, uint256 _minPriceEth) external {
        // 将NFT 从卖家转移到本合约托管  用户的nft ID 转到本合约
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

    // 给相关ID的nft 出价。关键字 payable 可支付
    function placeBid(uint256 _tokenId) external payable {
        Auction storage auction = auctions[_tokenId];
        // 判断价格是否高于最低起拍价
        require(auction.active, "Auction not active");
        require(msg.value > auction.minPriceEth && msg.value > auction.highestBid, "Bid to low");

        // 退还前一个最高出价者的资金
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

    // 结束拍卖并结算资金
    function settleAuction(uint256 _tokenId) external {
        Auction storage auction = auctions[_tokenId];
        require(auction.active, "Already settled");
        require(auction.highestBidder != address(0), "No winner!");

        auction.active = false;
        // 支付余款到卖家
        payable(auction.seller).transfer(auction.highestBid);

        // 转移NFT 给 获胜者.
        nftConntract.safeTransferFrom(address(this), auction.highestBidder, _tokenId);
        // 发送结束事件
        emit AuctionSettled(_tokenId, auction.highestBidder, auction.highestBid);
    }

    // UUPS 升级权限检查
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

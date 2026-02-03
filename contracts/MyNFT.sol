// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
// 引入openzeppelin的721实现和权限控制
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// 铸造合约 作为拍卖的对象
contract MyNFT is ERC721, Ownable {
    // 用于记录下一个铸造的token ID ，确保ID的唯一性
    uint256 private _nextTokenId;

    //初始化名称和代币符号 owner设置为部署者
    constructor() ERC721("AuctionNFT", "ANFT") Ownable(msg.sender) {}

    //铸造nft 合约所有者调用
    function mint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++; // ID 自增
        _safeMint(to, tokenId); // 安全铸造 确保地址能够接收nft
        return tokenId;
    }

    // 销毁nft 合约所有者调用
    function burn(uint256 id) external onlyOwner {
        // 确保当前持有该nft
        require(msg.sender == ownerOf(id), "no owner");
        _burn(id); // 销毁调用
    }
}

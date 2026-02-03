// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// 铸造合约 作为拍卖的对象
contract MyNFT is ERC721, Ownable {
    uint256 private _nextTokenId;

    constructor() ERC721("AuctionNFT", "ANFT") Ownable(msg.sender) {}

    function mint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function burn(uint256 id) external onlyOwner {
        require(msg.sender == ownerOf(id), "no owner");
        _burn(id);
    }
}

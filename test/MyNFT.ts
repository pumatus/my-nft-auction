import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("MyNFT 核心逻辑测试", function () {
  let nft: any;
  let owner: any;
  let otherAccount: any;

  // 在每个测试用例运行前，重新部署合约，保证测试环境干净
  beforeEach(async function () {
    // 获取账户：owner 通常是 deployer，otherAccount 是普通用户
    [owner, otherAccount] = await ethers.getSigners();

    // 部署合约 (Hardhat 3 快捷方式)
    // 注意：MyNFT 的 constructor 需要 Ownable(msg.sender)，这里默认就是 owner
    nft = await ethers.deployContract("MyNFT");
  });

  // --- 1. 部署测试 ---
  describe("Deployment", function () {
    it("名称和符号应当正确", async function () {
      expect(await nft.name()).to.equal("AuctionNFT");
      expect(await nft.symbol()).to.equal("ANFT");
    });

    it("合约所有者应当是部署者", async function () {
      expect(await nft.owner()).to.equal(owner.address);
    });
  });

  // --- 2. 铸造测试 (mint) ---
  describe("Minting", function () {
    it("管理员（Owner）可以成功铸造并发出事件", async function () {
      // 验证 mint 函数会发出 ERC721 标准的 Transfer 事件
      // 铸造时，from 是零地址
      await expect(nft.mint(owner.address))
        .to.emit(nft, "Transfer")
        .withArgs(ethers.ZeroAddress, owner.address, 0);

      // 验证余额增加
      expect(await nft.balanceOf(owner.address)).to.equal(1);
    });

    it("非管理员不能调用 mint", async function () {
      // 使用 connect(otherAccount) 切换调用者
      // 验证会触发 OpenZeppelin 的自定义错误 OwnableUnauthorizedAccount
      await expect(nft.connect(otherAccount).mint(otherAccount.address))
        .to.be.revertedWithCustomError(nft, "OwnableUnauthorizedAccount")
        .withArgs(otherAccount.address);
    });
  });

  // --- 3. 销毁测试 (burn) ---
  describe("Burning", function () {
    beforeEach(async function () {
      // 销毁前先铸造一个，ID 应该是 0
      await nft.mint(owner.address);
    });

    it("管理员可以销毁自己持有的 NFT", async function () {
      await expect(nft.burn(0))
        .to.emit(nft, "Transfer")
        .withArgs(owner.address, ethers.ZeroAddress, 0);

      expect(await nft.balanceOf(owner.address)).to.equal(0);
    });

    it("即使是管理员，如果没有持有该 ID 也不能销毁 (合约逻辑 require)", async function () {
      // 先把 ID 0 转给路人甲
      await nft.transferFrom(owner.address, otherAccount.address, 0);

      // 虽然是 owner 调用 burn，但合约内 require(msg.sender == ownerOf(id)) 会拦截
      await expect(nft.burn(0)).to.be.revertedWith("no owner");
    });
  });
});
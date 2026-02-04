const ethers = require("ethers");
const fs = require("fs");

async function run() {
    const pk = ""; // 填入 MetaMask 导出的私钥
    const pw = ""; // 填入加密密码
    const wallet = new ethers.Wallet(pk);
    const json = await wallet.encrypt(pw);
    fs.writeFileSync(`./keystore-${wallet.address}.json`, json);
    console.log("JSON 文件已生成！");
}
run();
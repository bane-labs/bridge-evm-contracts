import { vars } from "hardhat/config";
import { ethers } from "ethers";
import fs from "fs";

// Set a password for encrypting the wallet
const password = vars.has("WALLET_PASSWORD") ? vars.get("WALLET_PASSWORD") : "";
const filename = vars.has("WALLET_FILENAME") ? vars.get("WALLET_FILENAME") : "";

// Read and decrypt the wallet
async function readAndDecryptWallet() {
    var read = fs.readFileSync("wallets/" + filename + ".json");
    var wallet = ethers.Wallet.fromEncryptedJsonSync(read.toString(), password);
    console.log("Wallet address: " + wallet.address);
    console.log("Wallet private key: " + wallet.privateKey);
}

async function main() {
    await readAndDecryptWallet();
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

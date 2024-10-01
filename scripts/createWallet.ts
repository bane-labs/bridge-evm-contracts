import { vars } from "hardhat/config";
import { ethers } from "ethers";
import fs from "fs";

// Set a password for encrypting the wallet
const password = vars.has("WALLET_PASSWORD") ? vars.get("WALLET_PASSWORD") : "";
const filename = vars.has("WALLET_FILENAME") ? vars.get("WALLET_FILENAME") : "mywallet";

// Encrypt the wallet and save it to a file
async function saveEncryptedWallet() {
    const dirName = "wallets/";
    const walletDirExists = fs.existsSync(dirName);
    if (!walletDirExists) {
        const dir = fs.mkdirSync(dirName);
        console.log("Wallet directory created at " + dirName);
    }

    let wallet = ethers.Wallet.createRandom();
    console.log("Wallet address: " + wallet.address);
    console.log("Wallet private key: " + wallet.privateKey);

    const encryptedJson = await wallet.encrypt(password);
    fs.writeFileSync(dirName + filename + ".json", encryptedJson);
    console.log("Encrypted wallet saved to " + filename + ".json");
}

saveEncryptedWallet();

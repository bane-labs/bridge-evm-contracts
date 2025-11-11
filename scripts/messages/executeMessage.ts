import { ethers } from "hardhat";
import { fundIfLocalNetwork } from "../utils/network";
import { getMessageBridgeFromEnv } from "../utils/addresses";
import { getPersonalWallet } from "../utils/wallet";
import { DEFAULT_TX_OVERRIDES } from "../utils/constants";
import { MessageBridge } from "../../typechain-types";
import { Wallet } from "ethers";

async function executeMessage(messageBridge: MessageBridge, sender: Wallet, nonce: number): Promise<void> {
    await fundIfLocalNetwork([sender.address]);
    const message = await messageBridge.connect(sender).getEvmMessage(nonce);
    console.log("Executing message:", message);
    const tx = await messageBridge
        .connect(sender)
        .executeMessage(nonce, DEFAULT_TX_OVERRIDES);
    console.log("Transaction sent. Hash:", tx.hash);
    const receipt = await tx.wait();
    if (receipt) {
        console.log('Transaction mined. Status:', receipt.status);
    } else {
        throw new Error("Transaction receipt is null");
    }
}

async function main(): Promise<void> {
    const envNonce = process.env.NONCE;
    if (!envNonce) {
        throw new Error("Please set the NONCE environment variable");
    }

    const nonce = parseInt(envNonce, 10);
    if (isNaN(nonce)) {
        throw new Error("NONCE must be a valid number");
    }

    const sender = getPersonalWallet(ethers.provider);
    const messageBridge = await getMessageBridgeFromEnv();
    await executeMessage(messageBridge, sender, nonce);
}

main().catch((error) => {
    console.error("Error:", error.message);
    process.exitCode = 1;
});

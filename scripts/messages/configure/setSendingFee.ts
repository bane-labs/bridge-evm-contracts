import { ethers } from "hardhat";
import { DEFAULT_TX_OVERRIDES } from "../../utils/constants";
import { fundIfLocalNetwork } from "../../utils/network";
import { getGovernor } from "../../utils/wallet";

function requireEnv(name: string): string {
    const value = process.env[name];
    if (!value) {
        throw new Error(`${name} environment variable is required`);
    }
    return value;
}

function parseEtherEnv(name: string): bigint {
    const value = requireEnv(name);
    try {
        return ethers.parseEther(value);
    } catch {
        throw new Error(`${name} must be a valid decimal ETH amount (example: 0.02)`);
    }
}

async function main() {
    const messageBridgeAddress = requireEnv("MESSAGE_BRIDGE_ADDRESS");
    if (!ethers.isAddress(messageBridgeAddress)) {
        throw new Error("MESSAGE_BRIDGE_ADDRESS must be a valid address");
    }

    const newSendingFee = parseEtherEnv("SENDING_FEE");
    if (newSendingFee <= 0n) {
        throw new Error("SENDING_FEE must be greater than 0");
    }

    const governor = getGovernor(ethers.provider);
    await fundIfLocalNetwork([governor.address]);

    const messageBridge = await ethers.getContractAt("MessageBridge", messageBridgeAddress, governor);
    const currentSendingFee = await messageBridge.sendingFee();

    console.log(`Governor: ${governor.address}`);
    console.log(`MessageBridge: ${messageBridgeAddress}`);
    console.log(`Current sending fee: ${ethers.formatEther(currentSendingFee)} ETH`);
    console.log(`Requested sending fee: ${ethers.formatEther(newSendingFee)} ETH`);

    if (currentSendingFee === newSendingFee) {
        console.log("Sending fee already set to requested value.");
        return;
    }

    const tx = await messageBridge.connect(governor).setSendingFee(newSendingFee, DEFAULT_TX_OVERRIDES);
    console.log(`Submitting transaction: ${tx.hash}`);
    await tx.wait();

    const updatedSendingFee = await messageBridge.sendingFee();
    console.log(`Updated sending fee: ${ethers.formatEther(updatedSendingFee)} ETH`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

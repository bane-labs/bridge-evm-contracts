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
        throw new Error(`${name} must be a valid decimal ETH amount (example: 0.001)`);
    }
}

async function main() {
    const bridgeAddress = requireEnv("BRIDGE_ADDRESS");
    const tokenAddress = requireEnv("TOKEN_ADDRESS");
    const newFee = parseEtherEnv("TOKEN_WITHDRAWAL_FEE");

    if (!ethers.isAddress(bridgeAddress)) {
        throw new Error("BRIDGE_ADDRESS must be a valid address");
    }

    if (!ethers.isAddress(tokenAddress)) {
        throw new Error("TOKEN_ADDRESS must be a valid address");
    }

    if (newFee <= 0n) {
        throw new Error("TOKEN_WITHDRAWAL_FEE must be greater than 0");
    }

    const governor = getGovernor(ethers.provider);
    await fundIfLocalNetwork([governor.address]);

    const bridge = await ethers.getContractAt("TestBridge", bridgeAddress, governor);
    const isRegistered = await bridge.isRegisteredToken(tokenAddress);
    if (!isRegistered) {
        throw new Error(`Token ${tokenAddress} is not registered on this bridge`);
    }

    const tokenBridgeBefore = await bridge.tokenBridges(tokenAddress);

    console.log(`Governor: ${governor.address}`);
    console.log(`Bridge: ${bridgeAddress}`);
    console.log(`Token: ${tokenAddress}`);
    console.log(`Current token withdrawal fee: ${ethers.formatEther(tokenBridgeBefore.config.fee)} ETH`);
    console.log(`Requested token withdrawal fee: ${ethers.formatEther(newFee)} ETH`);

    if (tokenBridgeBefore.config.fee === newFee) {
        console.log("Token withdrawal fee already set to requested value.");
        return;
    }

    const tx = await bridge.connect(governor).setTokenWithdrawalFee([tokenAddress], [newFee], DEFAULT_TX_OVERRIDES);
    console.log(`Submitting transaction: ${tx.hash}`);
    await tx.wait();

    const tokenBridgeAfter = await bridge.tokenBridges(tokenAddress);
    console.log(`Updated token withdrawal fee: ${ethers.formatEther(tokenBridgeAfter.config.fee)} ETH`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

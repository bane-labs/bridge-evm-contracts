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
        throw new Error(`${name} must be a valid decimal ETH amount (example: 0.1)`);
    }
}

async function main() {
    const bridgeAddress = requireEnv("BRIDGE_ADDRESS");
    if (!ethers.isAddress(bridgeAddress)) {
        throw new Error("BRIDGE_ADDRESS must be a valid address");
    }

    const newMinAmount = parseEtherEnv("MIN_NATIVE_WITHDRAWAL");
    if (newMinAmount < 0n) {
        throw new Error("MIN_NATIVE_WITHDRAWAL cannot be negative");
    }

    const governor = getGovernor(ethers.provider);
    await fundIfLocalNetwork([governor.address]);

    const bridge = await ethers.getContractAt("TestBridge", bridgeAddress, governor);
    const nativeBridgeBefore = await bridge.nativeBridge();
    const decimalScalingFactor = BigInt(nativeBridgeBefore.config.decimalScalingFactor);
    const scalingDivisor = 10n ** decimalScalingFactor;

    if (newMinAmount % scalingDivisor !== 0n) {
        throw new Error(
            `MIN_NATIVE_WITHDRAWAL must be divisible by 10^${decimalScalingFactor.toString()} wei (${scalingDivisor.toString()})`
        );
    }

    console.log(`Governor: ${governor.address}`);
    console.log(`Bridge: ${bridgeAddress}`);
    console.log(`Current min native withdrawal amount: ${ethers.formatEther(nativeBridgeBefore.config.minAmount)} ETH`);
    console.log(`Current max native withdrawal amount: ${ethers.formatEther(nativeBridgeBefore.config.maxAmount)} ETH`);
    console.log(`Requested min native withdrawal amount: ${ethers.formatEther(newMinAmount)} ETH`);

    if (newMinAmount >= nativeBridgeBefore.config.maxAmount) {
        throw new Error(
            `MIN_NATIVE_WITHDRAWAL must be lower than current max withdrawal amount (${ethers.formatEther(nativeBridgeBefore.config.maxAmount)} ETH)`
        );
    }

    if (nativeBridgeBefore.config.minAmount === newMinAmount) {
        console.log("Min native withdrawal amount already set to requested value.");
        return;
    }

    const tx = await bridge.connect(governor).setMinNativeWithdrawalAmount(newMinAmount, DEFAULT_TX_OVERRIDES);
    console.log(`Submitting transaction: ${tx.hash}`);
    await tx.wait();

    const nativeBridgeAfter = await bridge.nativeBridge();
    console.log(`Updated min native withdrawal amount: ${ethers.formatEther(nativeBridgeAfter.config.minAmount)} ETH`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

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
    if (!ethers.isAddress(bridgeAddress)) {
        throw new Error("BRIDGE_ADDRESS must be a valid address");
    }

    const newFee = parseEtherEnv("NATIVE_WITHDRAWAL_FEE");
    if (newFee <= 0n) {
        throw new Error("NATIVE_WITHDRAWAL_FEE must be greater than 0");
    }

    const governor = getGovernor(ethers.provider);
    await fundIfLocalNetwork([governor.address]);

    const bridge = await ethers.getContractAt("TestBridge", bridgeAddress, governor);
    const nativeBridgeBefore = await bridge.nativeBridge();
    const decimalScalingFactor = BigInt(nativeBridgeBefore.config.decimalScalingFactor);
    const scalingDivisor = 10n ** decimalScalingFactor;

    if (newFee % scalingDivisor !== 0n) {
        throw new Error(
            `NATIVE_WITHDRAWAL_FEE must be divisible by 10^${decimalScalingFactor.toString()} wei (${scalingDivisor.toString()})`
        );
    }

    console.log(`Governor: ${governor.address}`);
    console.log(`Bridge: ${bridgeAddress}`);
    console.log(`Current native withdrawal fee: ${ethers.formatEther(nativeBridgeBefore.config.fee)} ETH`);
    console.log(`Requested native withdrawal fee: ${ethers.formatEther(newFee)} ETH`);

    if (nativeBridgeBefore.config.fee === newFee) {
        console.log("Native withdrawal fee already set to requested value.");
        return;
    }

    const tx = await bridge.connect(governor).setNativeWithdrawalFee(newFee, DEFAULT_TX_OVERRIDES);
    console.log(`Submitting transaction: ${tx.hash}`);
    await tx.wait();

    const nativeBridgeAfter = await bridge.nativeBridge();
    console.log(`Updated native withdrawal fee: ${ethers.formatEther(nativeBridgeAfter.config.fee)} ETH`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

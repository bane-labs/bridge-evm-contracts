import { ethers } from "hardhat";
import { getBridgeFromEnv } from "../utils/addresses";
import { fundIfLocalNetwork } from "../utils/network";
import { getGovernor } from "../utils/wallet";

export interface UnpauseConfig {
    title: string;
    checkPausedMethod: (bridge: any) => Promise<boolean>;
    unpauseMethod: (bridge: any, governor: any) => Promise<any>;
    tokenAddress?: string;
}

export async function executeUnpause(config: UnpauseConfig): Promise<void> {
    console.log(`\n${config.title}`);
    console.log("=".repeat(Math.max(40, config.title.length)));

    // Get the governor wallet
    const governor = getGovernor(ethers.provider);
    await fundIfLocalNetwork([governor.address]);

    console.log(`Governor address: ${governor.address}`);

    // Get the bridge contract
    const bridge = await getBridgeFromEnv(ethers.provider);
    const bridgeAddress = await bridge.getAddress();
    console.log(`Bridge address: ${bridgeAddress}`);

    try {
        // Check current status
        console.log(`\nChecking current ${config.title.toLowerCase()} status...`);
        const isPaused = await config.checkPausedMethod(bridge);
        console.log(`${config.title} paused: ${isPaused}`);

        if (isPaused) {
            console.log(`\nUnpausing ${config.title.toLowerCase()}...`);
            const tx = await config.unpauseMethod(bridge, governor);
            console.log(`Transaction hash: ${tx.hash}`);
            const receipt = await tx.wait();
            console.log(`${config.title} unpaused successfully! Gas used: ${receipt?.gasUsed.toString()}`);
        } else {
            console.log(`${config.title} is already unpaused!`);
        }

        // Verify final status
        console.log(`\nVerifying final ${config.title.toLowerCase()} status...`);
        const finalIsPaused = await config.checkPausedMethod(bridge);
        console.log(`${config.title} paused: ${finalIsPaused}`);

        console.log(`\n${config.title} unpause operation completed successfully!`);

    } catch (error: any) {
        console.error(`\nError during ${config.title.toLowerCase()} unpause:`);

        if (error.reason) {
            console.error(`Reason: ${error.reason}`);
        }

        if (error.code) {
            console.error(`Code: ${error.code}`);
        }

        if (error.message) {
            console.error(`Message: ${error.message}`);
        }

        throw error;
    }
}

export async function validateTokenAddress(tokenAddress?: string): Promise<string> {
    if (!tokenAddress) {
        throw new Error("TOKEN_ADDRESS environment variable is required");
    }

    if (!ethers.isAddress(tokenAddress)) {
        throw new Error(`Invalid token address: ${tokenAddress}`);
    }

    return tokenAddress;
}

export async function checkTokenRegistration(bridge: any, tokenAddress: string): Promise<void> {
    console.log("\nChecking token registration...");
    const tokenBridgeStruct = await bridge.tokenBridges(tokenAddress);
    const isRegistered = tokenBridgeStruct.config.fee > 0; // If fee is set, token is registered
    console.log(`Token registered: ${isRegistered}`);

    if (!isRegistered) {
        throw new Error(`Token ${tokenAddress} is not registered with the bridge`);
    }
}

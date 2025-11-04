import { ethers } from "hardhat";
import { getBridgeFromEnv } from "./utils/addresses";
import { fundIfLocalNetwork } from "./utils/network";
import { getGovernor } from "./utils/wallet";
import { DEFAULT_TX_OVERRIDES } from "./utils/constants";

/**
 * Script to unpause a specific token bridge
 *
 * This script will unpause the bridge for a specific token address, allowing
 * deposits and withdrawals for that token to resume.
 *
 * Usage:
 * TOKEN_ADDRESS=0x... npx hardhat run scripts/unpauseTokenBridge.ts --network <network>
 *
 * Requirements:
 * - TOKEN_ADDRESS environment variable must be set
 * - Governor wallet must have sufficient privileges
 * - Token must be registered with the bridge
 */

async function main() {
    const tokenAddress = process.env.TOKEN_ADDRESS;

    if (!tokenAddress) {
        throw new Error("TOKEN_ADDRESS environment variable is required");
    }

    if (!ethers.isAddress(tokenAddress)) {
        throw new Error(`Invalid token address: ${tokenAddress}`);
    }

    console.log(`\nUnpausing Token Bridge for: ${tokenAddress}`);
    console.log("=" .repeat(60));

    // Get the governor wallet
    const governor = getGovernor(ethers.provider);
    await fundIfLocalNetwork([governor.address]);

    console.log(`Governor address: ${governor.address}`);

    // Get the bridge contract
    const bridge = await getBridgeFromEnv(ethers.provider);
    const bridgeAddress = await bridge.getAddress();
    console.log(`Bridge address: ${bridgeAddress}`);

    try {
        // Check if token is registered by checking if it exists in tokenBridges mapping
        console.log("\nChecking token registration...");
        const tokenBridgeStruct = await bridge.tokenBridges(tokenAddress);
        const isRegistered = tokenBridgeStruct.config.fee > 0; // If fee is set, token is registered
        console.log(`Token registered: ${isRegistered}`);

        if (!isRegistered) {
            throw new Error(`Token ${tokenAddress} is not registered with the bridge`);
        }

        // Check current pause status using TestBridge helper method
        console.log("\nChecking current token bridge status...");
        const tokenBridgePaused = await bridge.getTokenbridgePaused(tokenAddress);
        console.log(`Token bridge paused: ${tokenBridgePaused}`);

        if (!tokenBridgePaused) {
            console.log("Token bridge is already unpaused!");
            return;
        }

        // Unpause the token bridge
        console.log(`\nUnpausing token bridge for ${tokenAddress}...`);
        const tx = await bridge.connect(governor).unpauseTokenBridge(tokenAddress, DEFAULT_TX_OVERRIDES);
        console.log(`Transaction hash: ${tx.hash}`);

        const receipt = await tx.wait();
        console.log(`Token bridge unpaused successfully!`);
        console.log(`Gas used: ${receipt?.gasUsed.toString()}`);
        console.log(`Block number: ${receipt?.blockNumber}`);

        // Verify the unpause
        console.log("\nVerifying unpause...");
        const updatedTokenBridgePaused = await bridge.getTokenbridgePaused(tokenAddress);
        console.log(`Token bridge paused: ${updatedTokenBridgePaused}`);

        if (updatedTokenBridgePaused) {
            throw new Error("Token bridge is still paused after unpause transaction");
        }

        console.log("\nToken bridge unpause completed successfully!");

    } catch (error: any) {
        console.error("\nError unpausing token bridge:");

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

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

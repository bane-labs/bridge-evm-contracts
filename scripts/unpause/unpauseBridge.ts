import { ethers } from "hardhat";
import { getBridgeFromEnv } from "../utils/addresses";
import { fundIfLocalNetwork } from "../utils/network";
import { getGovernor } from "../utils/wallet";
import { DEFAULT_TX_OVERRIDES } from "../utils/constants";

/**
 * Script to unpause the bridge
 *
 * This script will unpause the bridge contract.
 *
 * Usage:
 * npx hardhat run scripts/unpauseBridge.ts --network <network>
 *
 * Requirements:
 * - Governor wallet must have sufficient privileges
 * - Bridge must be deployed and accessible
 */

export async function main() {
    console.log(`\nUnpausing Bridge`);
    console.log("=" .repeat(40));

    // Get the governor wallet
    const governor = getGovernor(ethers.provider);
    await fundIfLocalNetwork([governor.address]);

    console.log(`Governor address: ${governor.address}`);

    // Get the bridge contract
    const bridge = await getBridgeFromEnv(ethers.provider);
    const bridgeAddress = await bridge.getAddress();
    console.log(`Bridge address: ${bridgeAddress}`);

    try {
        // Check current bridge status
        console.log("\nChecking current bridge status...");
        const bridgePaused = await bridge.getbridgePaused();
        console.log(`Bridge paused: ${bridgePaused}`);

        if (bridgePaused) {
            console.log("\nUnpausing bridge...");
            const tx = await bridge.connect(governor).unpauseBridge(DEFAULT_TX_OVERRIDES);
            console.log(`Transaction hash: ${tx.hash}`);
            const receipt = await tx.wait();
            console.log(`Bridge unpaused successfully! Gas used: ${receipt?.gasUsed.toString()}`);
        } else {
            console.log("Bridge is already unpaused!");
        }

        // Verify final status
        console.log("\nVerifying final bridge status...");
        const finalBridgePaused = await bridge.getbridgePaused();
        console.log(`Bridge paused: ${finalBridgePaused}`);

        console.log(`\nBridge unpause operation completed successfully!`);

    } catch (error: any) {
        console.error("\nError during bridge unpause:");

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

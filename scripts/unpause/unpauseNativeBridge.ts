import { ethers } from "hardhat";
import { getBridgeFromEnv } from "../utils/addresses";
import { fundIfLocalNetwork } from "../utils/network";
import { getGovernor } from "../utils/wallet";
import { DEFAULT_TX_OVERRIDES } from "../utils/constants";

/**
 * Script to unpause the native bridge specifically
 *
 * This script will unpause native bridge functionality specifically.
 *
 * Usage:
 * npx hardhat run scripts/unpauseNativeBridge.ts --network <network>
 *
 * Requirements:
 * - Governor wallet must have sufficient privileges
 * - Bridge must be deployed and accessible
 * - Native bridge must be configured
 */

export async function main() {
    console.log(`\nUnpausing Native Bridge`);
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
        // Check current native bridge status
        console.log("\nChecking current native bridge status...");
        const nativeBridgeStruct = await bridge.nativeBridge();
        const nativeBridgePaused = nativeBridgeStruct.paused;
        console.log(`Native bridge paused: ${nativeBridgePaused}`);

        if (nativeBridgePaused) {
            console.log("\nUnpausing native bridge...");
            const tx = await bridge.connect(governor).unpauseNativeBridge(DEFAULT_TX_OVERRIDES);
            console.log(`Transaction hash: ${tx.hash}`);
            const receipt = await tx.wait();
            console.log(`Native bridge unpaused successfully! Gas used: ${receipt?.gasUsed.toString()}`);
        } else {
            console.log("Native bridge is already unpaused!");
        }

        // Verify final status
        console.log("\nVerifying final native bridge status...");
        const finalNativeBridgeStruct = await bridge.nativeBridge();
        const finalNativeBridgePaused = finalNativeBridgeStruct.paused;
        console.log(`Native bridge paused: ${finalNativeBridgePaused}`);

        console.log(`\nNative bridge unpause operation completed successfully!`);

    } catch (error: any) {
        console.error("\nError during native bridge unpause:");

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

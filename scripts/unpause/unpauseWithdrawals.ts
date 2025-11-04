import { ethers } from "hardhat";
import { getBridgeFromEnv } from "../utils/addresses";
import { fundIfLocalNetwork } from "../utils/network";
import { getGovernor } from "../utils/wallet";
import { DEFAULT_TX_OVERRIDES } from "../utils/constants";

/**
 * Script to unpause bridge withdrawals
 *
 * This script will unpause withdrawal functionality on the bridge.
 *
 * Usage:
 * npx hardhat run scripts/unpauseWithdrawals.ts --network <network>
 *
 * Requirements:
 * - Governor wallet must have sufficient privileges
 * - Bridge must be deployed and accessible
 */

export async function main() {
    console.log(`\nUnpausing Bridge Withdrawals`);
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
        // Check current withdrawal status
        console.log("\nChecking current withdrawal status...");
        const withdrawalsPaused = await bridge.getWithdrawalsPaused();
        console.log(`Withdrawals paused: ${withdrawalsPaused}`);

        if (withdrawalsPaused) {
            console.log("\nUnpausing withdrawals...");
            const tx = await bridge.connect(governor).unpauseWithdrawals(DEFAULT_TX_OVERRIDES);
            console.log(`Transaction hash: ${tx.hash}`);
            const receipt = await tx.wait();
            console.log(`Withdrawals unpaused successfully! Gas used: ${receipt?.gasUsed.toString()}`);
        } else {
            console.log("Withdrawals are already unpaused!");
        }

        // Verify final status
        console.log("\nVerifying final withdrawal status...");
        const finalWithdrawalsPaused = await bridge.getWithdrawalsPaused();
        console.log(`Withdrawals paused: ${finalWithdrawalsPaused}`);

        console.log(`\nWithdrawals unpause operation completed successfully!`);

    } catch (error: any) {
        console.error("\nError during withdrawals unpause:");

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

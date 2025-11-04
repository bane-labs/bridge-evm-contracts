import { ethers } from "hardhat";
import { getBridgeFromEnv } from "./utils/addresses";
import { fundIfLocalNetwork } from "./utils/network";
import { getGovernor } from "./utils/wallet";
import { DEFAULT_TX_OVERRIDES } from "./utils/constants";

/**
 * Script to unpause the native bridge at all levels
 *
 * This script will unpause all aspects of the native bridge:
 * 1. Bridge itself (unpauseBridge)
 * 2. Withdrawals (unpauseWithdrawals)
 * 3. Native bridge specifically (unpauseNativeBridge)
 *
 * Usage:
 * npx hardhat run scripts/unpauseNativeBridge.ts --network <network>
 *
 * Requirements:
 * - Governor wallet must have sufficient privileges
 * - Bridge must be deployed and accessible
 * - Native bridge must be configured
 */

interface UnpauseResult {
    operation: string;
    success: boolean;
    txHash?: string;
    error?: string;
    alreadyUnpaused?: boolean;
}

async function main() {
    console.log(`\nUnpausing Native Bridge at All Levels`);
    console.log("=" .repeat(60));

    // Get the governor wallet
    const governor = getGovernor(ethers.provider);
    await fundIfLocalNetwork([governor.address]);

    console.log(`Governor address: ${governor.address}`);

    // Get the bridge contract
    const bridge = await getBridgeFromEnv(ethers.provider);
    const bridgeAddress = await bridge.getAddress();
    console.log(`Bridge address: ${bridgeAddress}`);

    const results: UnpauseResult[] = [];

    try {
        // Check initial bridge status using TestBridge helper methods
        console.log("\nChecking current bridge status...");
        const bridgePaused = await bridge.getbridgePaused();
        const withdrawalsPaused = await bridge.getWithdrawalsPaused();
        const nativeBridgeStruct = await bridge.nativeBridge();
        const nativeBridgePaused = nativeBridgeStruct.paused;

        console.log(`Bridge paused: ${bridgePaused}`);
        console.log(`Withdrawals paused: ${withdrawalsPaused}`);
        console.log(`Native bridge paused: ${nativeBridgePaused}`);

        // 1. Unpause the bridge
        console.log("\nStep 1: Unpausing bridge...");
        if (bridgePaused) {
            try {
                const tx1 = await bridge.connect(governor).unpauseBridge(DEFAULT_TX_OVERRIDES);
                console.log(`Transaction hash: ${tx1.hash}`);
                const receipt1 = await tx1.wait();
                results.push({
                    operation: "unpauseBridge",
                    success: true,
                    txHash: tx1.hash
                });
                console.log(`Bridge unpaused successfully! Gas used: ${receipt1?.gasUsed.toString()}`);
            } catch (error: any) {
                results.push({
                    operation: "unpauseBridge",
                    success: false,
                    error: error.message
                });
                console.log(`Failed to unpause main bridge: ${error.message}`);
            }
        } else {
            results.push({
                operation: "unpauseBridge",
                success: true,
                alreadyUnpaused: true
            });
            console.log("Main bridge is already unpaused!");
        }

        // 2. Unpause withdrawals
        console.log("\nStep 2: Unpausing withdrawals...");
        if (withdrawalsPaused) {
            try {
                const tx2 = await bridge.connect(governor).unpauseWithdrawals(DEFAULT_TX_OVERRIDES);
                console.log(`Transaction hash: ${tx2.hash}`);
                const receipt2 = await tx2.wait();
                results.push({
                    operation: "unpauseWithdrawals",
                    success: true,
                    txHash: tx2.hash
                });
                console.log(`Withdrawals unpaused successfully! Gas used: ${receipt2?.gasUsed.toString()}`);
            } catch (error: any) {
                results.push({
                    operation: "unpauseWithdrawals",
                    success: false,
                    error: error.message
                });
                console.log(`Failed to unpause withdrawals: ${error.message}`);
            }
        } else {
            results.push({
                operation: "unpauseWithdrawals",
                success: true,
                alreadyUnpaused: true
            });
            console.log("Withdrawals are already unpaused!");
        }

        // 3. Unpause native bridge specifically
        console.log("\nStep 3: Unpausing native bridge...");
        if (nativeBridgePaused) {
            try {
                const tx3 = await bridge.connect(governor).unpauseNativeBridge(DEFAULT_TX_OVERRIDES);
                console.log(`Transaction hash: ${tx3.hash}`);
                const receipt3 = await tx3.wait();
                results.push({
                    operation: "unpauseNativeBridge",
                    success: true,
                    txHash: tx3.hash
                });
                console.log(`Native bridge unpaused successfully! Gas used: ${receipt3?.gasUsed.toString()}`);
            } catch (error: any) {
                results.push({
                    operation: "unpauseNativeBridge",
                    success: false,
                    error: error.message
                });
                console.log(`Failed to unpause native bridge: ${error.message}`);
            }
        } else {
            results.push({
                operation: "unpauseNativeBridge",
                success: true,
                alreadyUnpaused: true
            });
            console.log("Native bridge is already unpaused!");
        }

        // Verify final status
        console.log("\nVerifying final bridge status...");
        const finalBridgePaused = await bridge.getbridgePaused();
        const finalWithdrawalsPaused = await bridge.getWithdrawalsPaused();
        const finalNativeBridgeStruct = await bridge.nativeBridge();
        const finalNativeBridgePaused = finalNativeBridgeStruct.paused;

        console.log(`Bridge paused: ${finalBridgePaused}`);
        console.log(`Withdrawals paused: ${finalWithdrawalsPaused}`);
        console.log(`Native bridge paused: ${finalNativeBridgePaused}`);

        // Summary
        console.log("\nSummary of Operations:");
        console.log("=" .repeat(60));

        results.forEach((result, index) => {
            const status = result.alreadyUnpaused ? "(already unpaused)" :
                          result.success ? "(success)" : `(failed: ${result.error})`;

            console.log(`${index + 1}. ${result.operation} ${status}`);
            if (result.txHash) {
                console.log(`   Transaction: ${result.txHash}`);
            }
        });

        const allSuccess = results.every(r => r.success);
        const anyUnpaused = results.some(r => !r.alreadyUnpaused && r.success);

        if (allSuccess) {
            console.log(`\nNative bridge unpause completed ${anyUnpaused ? 'successfully' : '(all components were already unpaused)'}!`);
        } else {
            console.log("\nSome operations failed. Check the summary above for details.");
        }

    } catch (error: any) {
        console.error("\nFatal error during native bridge unpause:");

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

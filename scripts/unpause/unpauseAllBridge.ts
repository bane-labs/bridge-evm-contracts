import { ethers } from "hardhat";

/**
 * Script to unpause all aspects of the bridge system
 *
 * This script orchestrates the unpausing of all bridge components by
 * reusing the logic from individual unpause scripts:
 * 1. Main bridge (unpauseBridge)
 * 2. Withdrawals (unpauseWithdrawals)
 * 3. Native bridge (unpauseNativeBridge)
 * 4. Token bridges for specified tokens (unpauseTokenBridge)
 *
 * For individual operations, use the specific scripts:
 * - scripts/unpause/unpauseBridge.ts
 * - scripts/unpause/unpauseWithdrawals.ts
 * - scripts/unpause/unpauseNativeBridge.ts
 * - scripts/unpause/unpauseTokenBridge.ts
 *
 * Usage:
 * npx hardhat run scripts/unpause/unpauseAllBridge.ts --network <network>
 *
 * Optional environment variables:
 * - TOKEN_ADDRESSES: Comma-separated list of token addresses to unpause (e.g., "0x123...,0x456...")
 *
 * Requirements:
 * - Governor wallet must have sufficient privileges
 * - Bridge must be deployed and accessible
 */

interface UnpauseOperation {
    name: string;
    success: boolean;
    error?: string;
}

// Import the main functions from individual unpause scripts
async function unpauseBridgeLogic(): Promise<void> {
    const { main: unpauseBridge } = await import("./unpauseBridge");
    await unpauseBridge();
}

async function unpauseWithdrawalsLogic(): Promise<void> {
    const { main: unpauseWithdrawals } = await import("./unpauseWithdrawals");
    await unpauseWithdrawals();
}

async function unpauseNativeBridgeLogic(): Promise<void> {
    const { main: unpauseNativeBridge } = await import("./unpauseNativeBridge");
    await unpauseNativeBridge();
}

async function unpauseTokenBridgeLogic(tokenAddress: string): Promise<void> {
    // Set the TOKEN_ADDRESS environment variable for the token bridge script
    const originalTokenAddress = process.env.TOKEN_ADDRESS;
    process.env.TOKEN_ADDRESS = tokenAddress;

    try {
        const { main: unpauseTokenBridge } = await import("./unpauseTokenBridge");
        await unpauseTokenBridge();
    } finally {
        // Restore original environment variable
        if (originalTokenAddress) {
            process.env.TOKEN_ADDRESS = originalTokenAddress;
        } else {
            delete process.env.TOKEN_ADDRESS;
        }
    }
}

async function main() {
    console.log(`\nUnpausing All Bridge Components`);
    console.log("=".repeat(60));

    // Parse token addresses from environment variable
    const tokenAddressesStr = process.env.TOKEN_ADDRESSES;
    const tokenAddresses = tokenAddressesStr
        ? tokenAddressesStr.split(',').map(addr => addr.trim()).filter(addr => ethers.isAddress(addr))
        : [];

    if (tokenAddressesStr && tokenAddresses.length === 0) {
        console.warn("TOKEN_ADDRESSES provided but no valid addresses found");
    }

    console.log(`Token addresses to unpause: ${tokenAddresses.length > 0 ? tokenAddresses.join(', ') : 'None'}`);

    const operations: UnpauseOperation[] = [];

    console.log("\nStarting unpause operations...");
    console.log("-".repeat(40));

    // 1. Unpause the main bridge
    console.log("\n1. Unpausing main bridge...");
    try {
        await unpauseBridgeLogic();
        operations.push({
            name: "Main Bridge",
            success: true
        });
        console.log("Main bridge unpause completed");
    } catch (error: any) {
        operations.push({
            name: "Main Bridge",
            success: false,
            error: error.message
        });
        console.error(`Failed to unpause main bridge: ${error.message}`);
    }

    // 2. Unpause withdrawals
    console.log("\n2. Unpausing withdrawals...");
    try {
        await unpauseWithdrawalsLogic();
        operations.push({
            name: "Withdrawals",
            success: true
        });
        console.log("Withdrawals unpause completed");
    } catch (error: any) {
        operations.push({
            name: "Withdrawals",
            success: false,
            error: error.message
        });
        console.error(`Failed to unpause withdrawals: ${error.message}`);
    }

    // 3. Unpause native bridge
    console.log("\n3. Unpausing native bridge...");
    try {
        await unpauseNativeBridgeLogic();
        operations.push({
            name: "Native Bridge",
            success: true
        });
        console.log("Native bridge unpause completed");
    } catch (error: any) {
        operations.push({
            name: "Native Bridge",
            success: false,
            error: error.message
        });
        console.error(`Failed to unpause native bridge: ${error.message}`);
    }

    // 4. Unpause token bridges
    if (tokenAddresses.length > 0) {
        console.log("\n4. Unpausing token bridges...");

        for (let i = 0; i < tokenAddresses.length; i++) {
            const tokenAddress = tokenAddresses[i];

            try {
                await unpauseTokenBridgeLogic(tokenAddress);
                operations.push({
                    name: `Token Bridge (${tokenAddress})`,
                    success: true
                });
                console.log(`Token bridge ${tokenAddress} unpause completed`);
            } catch (error: any) {
                operations.push({
                    name: `Token Bridge (${tokenAddress})`,
                    success: false,
                    error: error.message
                });
                console.error(`Failed to unpause token bridge ${tokenAddress}: ${error.message}`);
            }
        }
    } else {
        console.log("\n4. No token addresses specified - skipping token bridge unpause");
    }

    // Summary report
    console.log("\nOperation Summary:");
    console.log("=".repeat(60));

    let totalOperations = 0;
    let successfulOperations = 0;
    let failedOperations = 0;

    operations.forEach((operation, index) => {
        totalOperations++;
        const status = operation.success ? "(success)" : `(failed: ${operation.error})`;
        console.log(`${index + 1}. ${operation.name} ${status}`);

        if (operation.success) {
            successfulOperations++;
        } else {
            failedOperations++;
        }
    });

    console.log("\nSummary Statistics:");
    console.log(`Total operations: ${totalOperations}`);
    console.log(`Successful operations: ${successfulOperations}`);
    console.log(`Failed operations: ${failedOperations}`);

    if (failedOperations === 0) {
        console.log("\nAll bridge components unpause operations completed!");
    } else {
        console.log(`\nSome operations failed (${failedOperations}/${totalOperations}). Check individual logs above for details.`);
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

import { ethers } from "hardhat";
import { executeUnpause, UnpauseConfig } from "./unpauseUtils";
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
    const config: UnpauseConfig = {
        title: "Bridge Withdrawals",
        checkPausedMethod: async (bridge) => await bridge.getWithdrawalsPaused(),
        unpauseMethod: async (bridge, governor) =>
            await bridge.connect(governor).unpauseWithdrawals(DEFAULT_TX_OVERRIDES)
    };

    await executeUnpause(config);
}

// Only execute main() if this script is run directly (not imported)
if (require.main === module) {
    main().catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}

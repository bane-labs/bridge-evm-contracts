import { ethers } from "hardhat";
import { executeUnpause, UnpauseConfig } from "./unpauseUtils";
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
    const config: UnpauseConfig = {
        title: "Bridge",
        checkPausedMethod: async (bridge) => await bridge.getbridgePaused(),
        unpauseMethod: async (bridge, governor) =>
            await bridge.connect(governor).unpauseBridge(DEFAULT_TX_OVERRIDES)
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

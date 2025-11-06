import { ethers } from "hardhat";
import { executeUnpause, UnpauseConfig } from "./unpauseUtils";
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
    const config: UnpauseConfig = {
        title: "Native Bridge",
        checkPausedMethod: async (bridge) => {
            const nativeBridgeStruct = await bridge.nativeBridge();
            return nativeBridgeStruct.paused;
        },
        unpauseMethod: async (bridge, governor) =>
            await bridge.connect(governor).unpauseNativeBridge(DEFAULT_TX_OVERRIDES)
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

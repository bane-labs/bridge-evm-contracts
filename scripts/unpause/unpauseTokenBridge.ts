import { ethers } from "hardhat";
import { validateTokenAddress, checkTokenRegistration, executeUnpause, UnpauseConfig } from "./unpauseUtils";
import { DEFAULT_TX_OVERRIDES } from "../utils/constants";
import { getBridgeFromEnv } from "../utils/addresses";

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

export async function main() {
    const tokenAddress = await validateTokenAddress(process.env.TOKEN_ADDRESS);

    // Custom pre-check for token registration
    const bridge = await getBridgeFromEnv(ethers.provider);
    await checkTokenRegistration(bridge, tokenAddress);

    const config: UnpauseConfig = {
        title: `Token Bridge (${tokenAddress})`,
        checkPausedMethod: async (bridge) => await bridge.getTokenbridgePaused(tokenAddress),
        unpauseMethod: async (bridge, governor) =>
            await bridge.connect(governor).unpauseTokenBridge(tokenAddress, DEFAULT_TX_OVERRIDES),
        tokenAddress: tokenAddress
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

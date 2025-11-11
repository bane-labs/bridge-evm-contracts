import { getPersonalWallet } from '../utils/wallet';
import { decodeMessageBridgeError, getNonceFromEnv, MessageBridgeUtils } from '../utils/messageBridgeUtils';
import { ethers } from 'hardhat';

async function getExecutionResult(messageBridgeUtils: MessageBridgeUtils, nonce: bigint): Promise<void> {
    try {
        await messageBridgeUtils.getExecutableState(nonce);
    } catch (error: any) {
        console.error(`Error getting execution result for nonce ${nonce}:`);
        if (error.data) {
            console.error('Decoded error:', decodeMessageBridgeError(error.data));
        } else {
            console.error('Error message:', error.message);
        }
    }

    // Get the Neo execution result
    await messageBridgeUtils.getNeoExecutionResult(nonce);
}

async function main(): Promise<void> {
    const sender = getPersonalWallet(ethers.provider);
    const messageBridgeUtils = await MessageBridgeUtils.createFromHHVars(sender);

    await getExecutionResult(messageBridgeUtils, getNonceFromEnv());
}

main().catch((error) => {
    console.error('Error:', error.message);
    process.exitCode = 1;
});


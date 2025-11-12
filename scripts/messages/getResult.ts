import { getPersonalWallet } from '../utils/wallet';
import { decodeMessageBridgeError, getNonceFromEnv, MessageBridgeWrapper } from '../utils/messageBridgeUtils';
import { ethers } from 'hardhat';

async function getExecutionResult(messageBridgeWrapper: MessageBridgeWrapper, nonce: bigint): Promise<void> {
    try {
        await messageBridgeWrapper.getExecutableState(nonce);
        await messageBridgeWrapper.getEvmExecutionResult(nonce);
    } catch (error: any) {
        console.error(`Error getting execution result for nonce ${nonce}:`);
        if (error.data) {
            console.error('Decoded error:', decodeMessageBridgeError(error.data));
        } else {
            console.error('Error message:', error.message);
        }
    }

    // Get the Neo execution result
    await messageBridgeWrapper.getNeoExecutionResult(nonce);
}

async function main(): Promise<void> {
    const sender = getPersonalWallet(ethers.provider);
    const messageBridgeWrapper = await MessageBridgeWrapper.createFromHHVars(sender);

    await getExecutionResult(messageBridgeWrapper, getNonceFromEnv());
}

main().catch((error) => {
    console.error('Error:', error.message);
    process.exitCode = 1;
});


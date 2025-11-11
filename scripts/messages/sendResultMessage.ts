import { ethers } from 'hardhat';
import { getPersonalWallet } from '../utils/wallet';
import { decodeMessageBridgeError, getNonceFromEnv, MessageBridgeUtils } from '../utils/messageBridgeUtils';

async function main(): Promise<void> {
    const sender = getPersonalWallet(ethers.provider);
    const messageBridgeUtils = await MessageBridgeUtils.createFromHHVars(sender);

    let nonce = getNonceFromEnv();
    try {
        await messageBridgeUtils.sendResultMessage(nonce);
    } catch (e: any) {
        console.error(`Failed to send result message with nonce ${nonce}:`);
        if (e.data) {
            console.error('Decoded error:', decodeMessageBridgeError(e.data));
        } else {
            console.error('Error message:', e.message);
        }
    }
}

main().catch((error) => {
    console.error('Error:', error.message);
    process.exitCode = 1;
});

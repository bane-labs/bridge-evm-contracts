import { getPersonalWallet } from '../utils/wallet';
import { getNonceFromEnv, MessageBridgeWrapper } from '../utils/messageBridgeUtils';
import { ethers } from 'hardhat';
import { AbiCoder } from 'ethers';

async function getMessageWithDetails(messageBridgeWrapper: MessageBridgeWrapper, nonce: bigint): Promise<void> {

    const storedMessage = await messageBridgeWrapper.getMessage(nonce);

    let decodedMetadata;
    const abiCoder = new ethers.AbiCoder();
    if (storedMessage.encodedMetadata.length > 2) {

        const type = getMetadataType(abiCoder, storedMessage);

        let metadataStructAbi = getMetadataStructAbi(type);

        decodedMetadata = abiCoder.decode(metadataStructAbi, storedMessage.encodedMetadata);
        console.log(`Decoded Metadata (Type ${type}):`, decodedMetadata);
    }

    console.log('Raw Message:', storedMessage.rawMessage);
    if (decodedMetadata && decodedMetadata[0].msgType === 0n) {
        console.log('Decoding Call Structure...');
        try {
            const callStructAbi = ['tuple(address target, bool allowFailure, uint256 value, bytes callData)'];
            const decodedCall = abiCoder.decode(callStructAbi, storedMessage.rawMessage);
            console.log('Decoded Call Structure:', decodedCall);
        } catch (e) {
            throw new Error('Failed to get call structure ABI');
        }
    }
}

function getMetadataType(
    abiCoder: AbiCoder, storedMessage: [encodedMetadata: string, rawMessage: string] & {
        encodedMetadata: string;
        rawMessage: string
    }) {
    // First decode just the type to determine the structure
    const typeAbi = ['uint8'];
    const [type] = abiCoder.decode(typeAbi, storedMessage.encodedMetadata);
    return type;
}

function getMetadataStructAbi(type: bigint): string[] {
    let metadataStructAbi: string[];
    switch (Number(type)) {
        case 0: // EXECUTABLE
            console.log('Metadata type is EXECUTABLE');
            metadataStructAbi = ['tuple(uint8 msgType, uint256 timestamp, address sender, bool storeResult)'];
            break;
        case 1: // STORE_ONLY
            console.log('Metadata type is STORE_ONLY');
            metadataStructAbi = ['tuple(uint8 msgType, uint256 timestamp, address sender)'];
            break;
        case 2: // RESULT
            console.log('Metadata type is RESULT');
            metadataStructAbi = ['tuple(uint8 msgType, uint256 timestamp, address sender, uint256 relatedMessageNonce)'];
            break;
        default:
            throw new Error(`Unknown metadata type: ${type}`);
    }
    return metadataStructAbi;
}

async function main(): Promise<void> {
    const sender = getPersonalWallet(ethers.provider);
    const messageBridgeWrapper = await MessageBridgeWrapper.createFromHHVars(sender);
    await getMessageWithDetails(messageBridgeWrapper, getNonceFromEnv());
}

main().catch((error) => {
    console.error('Error:', error.message);
    process.exitCode = 1;
});

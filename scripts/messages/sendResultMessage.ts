import { ethers } from 'hardhat';
import { fundIfLocalNetwork } from '../utils/network';
import { getMessageBridgeFromEnv } from '../utils/addresses';
import { getPersonalWallet } from '../utils/wallet';
import { DEFAULT_TX_OVERRIDES } from '../utils/constants';
import { MessageBridge } from '../../typechain-types';
import { Wallet } from 'ethers';

async function sendTestMessageResult(messageBridge: MessageBridge, sender: Wallet, nonce: number): Promise<void> {
    await fundIfLocalNetwork([sender.address]);

    const fee = await messageBridge.sendingFee();
    console.log('Current sending fee:', ethers.formatEther(fee), 'ETH');
    let result;
    try {
        result = await messageBridge.getEvmExecutionResult(nonce);
    } catch (e) {
        console.log('No execution result found for nonce', nonce);
        return;
    }
    console.log('Current execution result for nonce', nonce, ':', result);

    // Get and print the EVM to NeoN3 state root
    let evmToNeoState = await messageBridge.evmToNeoState();
    console.log('EVM to NeoN3 state root:', evmToNeoState.root);
    console.log('EVM to NeoN3 state nonce:', evmToNeoState.nonce.toString());
    // Get and print the NeoN3 to EVM state root
    const neoToEvmState = await messageBridge.neoToEvmState();
    console.log('NeoN3 to EVM state root:', neoToEvmState.root);
    console.log('NeoN3 to EVM state nonce:', neoToEvmState.nonce.toString());

    let txr = await messageBridge.connect(sender).sendResultMessage(nonce, {value: fee, ...DEFAULT_TX_OVERRIDES});

    const response = await txr.wait();
    console.log("Result message sent. Transaction hash:", txr.hash);
    console.log("Transaction mined. Status:", response?.status ?? 'unknown');

    // Get and print the EVM to NeoN3 state root
    evmToNeoState = await messageBridge.evmToNeoState();
    console.log('New EVM to NeoN3 state root:', evmToNeoState.root);
    console.log('New EVM to NeoN3 state nonce:', evmToNeoState.nonce.toString());
}

async function main(): Promise<void> {
    const envNonce = process.env.NONCE;
    if (!envNonce) {
        throw new Error('Please set the NONCE environment variable');
    }

    const nonce = parseInt(envNonce, 10);
    if (isNaN(nonce)) {
        throw new Error('NONCE must be a valid number');
    }

    const messageBridge = await getMessageBridgeFromEnv();
    const sender = getPersonalWallet(ethers.provider);
    await sendTestMessageResult(messageBridge, sender, nonce);
}

main().catch((error) => {
    console.error('Error:', error.message);
    process.exitCode = 1;
});

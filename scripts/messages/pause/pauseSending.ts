import {ethers} from 'hardhat';
import {DEFAULT_TX_OVERRIDES} from '../../utils/constants';
import { PauseResult, performPause } from '../../utils/pausingHelper';
import { getGovernorFundedIfLocal, getMessageBridge } from '../helper';
import { MessageBridge } from '../../../typechain-types';
import { Wallet } from 'ethers';

export async function checkAndPauseSending(messageBridge: MessageBridge, governor: Wallet): Promise<PauseResult> {
    // Unpause the message bridge
    return await performPause(
        'Message Sending',
        () => messageBridge.sendingPaused(),
        () => messageBridge.connect(governor).pauseSending(DEFAULT_TX_OVERRIDES),
        {
            errorName: 'SendingNotPaused', // todo
            errorSelector: '0x26e7ced5',
        }
    );
}

async function main() {
    const messageBridge = await getMessageBridge();
    const governor = await getGovernorFundedIfLocal(ethers.provider);

    const pauseResult = await checkAndPauseSending(messageBridge, governor);

    if (pauseResult.alreadyPaused) {
        console.log('Message sending is already paused');
        return;
    } else {
        if (pauseResult.success) {
            console.log('Message sending has been successfully paused in tx:', pauseResult.txHash);
        } else {
            console.error('Failed to pause message sending:', pauseResult.error);
        }
    }
}

// Run if executed directly
if (require.main === module) {
  main().catch((error) => {
    console.error('Script failed:', error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}

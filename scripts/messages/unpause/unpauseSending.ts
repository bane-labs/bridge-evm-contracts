import {ethers} from 'hardhat';
import {DEFAULT_TX_OVERRIDES} from '../../utils/constants';
import { performUnpause, UnpauseResult } from '../../utils/pausingHelper';
import { getGovernorFundedIfLocal, getMessageBridge } from '../helper';
import { MessageBridge } from '../../../typechain-types';
import { Wallet } from 'ethers';

export async function checkAndUnpauseSending(messageBridge: MessageBridge, governor: Wallet): Promise<UnpauseResult> {
    // Unpause the message bridge
    return await performUnpause(
        'Message Sending',
        () => messageBridge.sendingPaused(),
        () => messageBridge.connect(governor).unpauseSending(DEFAULT_TX_OVERRIDES),
        {
            errorName: 'SendingNotPaused',
            errorSelector: '0x26e7ced5',
        }
    );
}

async function main() {
    const messageBridge = await getMessageBridge();
    const governor = await getGovernorFundedIfLocal(ethers.provider);

    const pauseResult = await checkAndUnpauseSending(messageBridge, governor);

    if (pauseResult.alreadyUnpaused) {
        console.log('Message sending is already unpaused');
        return;
    } else {
        if (pauseResult.success) {
            console.log('Message sending has been successfully unpaused in tx:', pauseResult.txHash);
        } else {
            console.error('Failed to unpause message sending:', pauseResult.error);
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

import { ethers } from 'hardhat';
import { DEFAULT_TX_OVERRIDES } from '../../utils/constants';
import { getGovernorFundedIfLocal, getMessageBridge } from '../helper';
import { performUnpause, PausingActionResult } from '../../utils/pausingHelper';
import { MessageBridge } from '../../../typechain-types';
import { Wallet } from 'ethers';

export async function checkAndUnpauseExecuting(messageBridge: MessageBridge, governor: Wallet): Promise<PausingActionResult> {
    return await performUnpause(
        'Message Execution',
        () => messageBridge.executingPaused(),
        () => messageBridge.connect(governor).unpauseExecuting(DEFAULT_TX_OVERRIDES),
        {
            errorName: 'ExecutingNotPaused',
            errorSelector: '0x61654835',
        }
    );
}

async function main() {
    const messageBridge = await getMessageBridge();
    const governor = await getGovernorFundedIfLocal(ethers.provider);

    const pauseResult = await checkAndUnpauseExecuting(messageBridge, governor);

    if (pauseResult.actionRedundant) {
        console.log('Message executing is already unpaused');
        return;
    } else {
        if (pauseResult.success) {
            console.log('Message executing has been successfully unpaused in tx:', pauseResult.txHash);
        } else {
            console.error('Failed to unpause Message executing:', pauseResult.error);
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

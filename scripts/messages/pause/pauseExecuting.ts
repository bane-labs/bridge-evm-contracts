import { ethers } from 'hardhat';
import { DEFAULT_TX_OVERRIDES } from '../../utils/constants';
import { getGovernorFundedIfLocal, getMessageBridge } from '../helper';
import { PausingActionResult, performPause } from '../../utils/pausingHelper';
import { MessageBridge } from '../../../typechain-types';
import { Wallet } from 'ethers';

export async function checkAndPauseExecuting(messageBridge: MessageBridge, governor: Wallet): Promise<PausingActionResult> {
    return await performPause(
        'Message Execution',
        () => messageBridge.executingPaused(),
        () => messageBridge.connect(governor).pauseExecuting(DEFAULT_TX_OVERRIDES),
        {
            errorName: 'ExecutingPaused',
            errorSelector: '0xf4700efc',
        }
    );
}

async function main() {
    const messageBridge = await getMessageBridge();
    const governor = await getGovernorFundedIfLocal(ethers.provider);

    const pauseResult = await checkAndPauseExecuting(messageBridge, governor);

    if (pauseResult.actionRedundant) {
        console.log('Message executing is already paused');
        return;
    } else {
        if (pauseResult.success) {
            console.log('Message executing has been successfully paused in tx:', pauseResult.txHash);
        } else {
            console.error('Failed to pause Message executing:', pauseResult.error);
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

import { ethers } from 'hardhat';
import { DEFAULT_TX_OVERRIDES } from '../../utils/constants';
import { PausingActionResult, performPause } from '../../utils/pausingHelper';
import { getGovernorFundedIfLocal, getMessageBridge } from '../helper';
import { MessageBridge } from '../../../typechain-types';
import { Wallet } from 'ethers';

export async function checkAndPause(messageBridge: MessageBridge, governor: Wallet): Promise<PausingActionResult> {
    return await performPause(
        'Message Bridge',
        () => messageBridge.messageBridgePaused(),
        () => messageBridge.connect(governor).pause(DEFAULT_TX_OVERRIDES),
        {
          errorName: 'MessageBridgePaused',
          errorSelector: '0xa4c897b0',
        }
    );
}

async function main() {
    const messageBridge = await getMessageBridge();
    const governor = await getGovernorFundedIfLocal(ethers.provider);

    const pauseResult = await checkAndPause(messageBridge, governor);

    if (pauseResult.actionRedundant) {
        console.log('MessageBridge is already paused');
        return;
    } else {
        if (pauseResult.success) {
            console.log('MessageBridge has been successfully paused in tx:', pauseResult.txHash);
        } else {
            console.error('Failed to pause MessageBridge:', pauseResult.error);
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

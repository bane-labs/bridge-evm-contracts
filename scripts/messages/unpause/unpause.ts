import { ethers } from 'hardhat';
import { DEFAULT_TX_OVERRIDES } from '../../utils/constants';
import { PausingActionResult, performUnpause } from '../../utils/pausingHelper';
import { getGovernorFundedIfLocal, getMessageBridge } from '../helper';
import { MessageBridge } from '../../../typechain-types';
import { Wallet } from 'ethers';

export async function checkAndUnpause(messageBridge: MessageBridge, governor: Wallet): Promise<PausingActionResult> {
    return await performUnpause(
        'Message Bridge',
        () => messageBridge.messageBridgePaused(),
        () => messageBridge.connect(governor).unpause(DEFAULT_TX_OVERRIDES),
        {
          errorName: 'MessageBridgeNotPaused',
          errorSelector: '0xfa5fc19e',
        }
    );
}

async function main() {
    const messageBridge = await getMessageBridge();
    const governor = await getGovernorFundedIfLocal(ethers.provider);

    const pauseResult = await checkAndUnpause(messageBridge, governor);

    if (pauseResult.actionRedundant) {
        console.log('MessageBridge is already unpaused');
        return;
    } else {
        if (pauseResult.success) {
            console.log('MessageBridge has been successfully unpaused in tx:', pauseResult.txHash);
        } else {
            console.error('Failed to unpause MessageBridge:', pauseResult.error);
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

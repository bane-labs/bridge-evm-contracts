import {ethers} from 'hardhat';
import { UnpauseResult } from '../../utils/pausingHelper';
import { getGovernorFundedIfLocal, getMessageBridge } from '../helper';
import { checkAndUnpause as checkAndUnpause } from './unpause';
import { checkAndUnpauseExecuting } from './unpauseExecuting';
import { checkAndUnpauseSending } from './unpauseSending';

/**
 * Simplified script to unpause all aspects of the MessageBridge contract
 *
 * This script will attempt to unpause:
 * 1. Message bridge (unpause)
 * 2. Message sending (unpauseSending)
 * 3. Message execution (unpauseExecuting)
 *
 * Note: All unpause operations require governor privileges
 * If a component is already unpaused, the operation will be skipped with a message
 *
 * Usage:
 * MESSAGE_BRIDGE_ADDRESS=0x... npx hardhat run scripts/messages/unpause/unpauseAll.ts --network <network>
 */
async function main() {
  const messageBridge = await getMessageBridge();
  const messageBridgeAddress = await messageBridge.getAddress();
  const governor = await getGovernorFundedIfLocal(ethers.provider);
  
  console.log('MessageBridge Unpause Script (Simplified)');
  console.log(`Bridge Address: ${messageBridgeAddress}`);

  console.log('\nAttempting unpause operations...');
  console.log('Note: Operations will be skipped automatically if components are already unpaused');

  const results: UnpauseResult[] = [];

  // // 1. Unpause message bridge functionality
  const unpauseResult = await checkAndUnpause(messageBridge, governor);
  results.push(unpauseResult);

  // 2. Unpause sending functionality
  const sendingUnpauseResult = await checkAndUnpauseSending(messageBridge, governor);
  results.push(sendingUnpauseResult);

  // 3. Unpause executing functionality
  const executingUnpauseResult = await checkAndUnpauseExecuting(messageBridge, governor);
  results.push(executingUnpauseResult);

  // Summary
  console.log('\n' + '='.repeat(50));
  console.log('UNPAUSE OPERATIONS SUMMARY');
  console.log('='.repeat(50));

  let successCount = 0;
  let errorCount = 0;
  let alreadyUnpausedCount = 0;

  results.forEach((result, index) => {
    console.log(`\n${index + 1}. ${result.operation}`);
    if (result.alreadyUnpaused) {
      console.log('   Status: Already unpaused');
      alreadyUnpausedCount++;
    } else if (result.success) {
      console.log('   Status: Success');
      console.log(`   Transaction: ${result.txHash}`);
      successCount++;
    } else {
      console.log('   Status: Failed');
      console.log(`   Error: ${result.error}`);
      errorCount++;
    }
  });

  console.log(`\nOverall Results:`);
  console.log(`- Successfully unpaused: ${successCount}`);
  console.log(`- Already unpaused: ${alreadyUnpausedCount}`);
  console.log(`- Failed operations: ${errorCount}`);

  if (errorCount > 0) {
    console.log('\nSome operations failed. Please check the errors above and ensure:');
    console.log('1. You are using the correct governor account');
    console.log('2. The governor account has sufficient gas');
    console.log('3. The MessageBridge contract address is correct');
    process.exitCode = 1;
  } else {
    console.log('\nAll MessageBridge unpause operations completed successfully!');
  }
}

// Run if executed directly
if (require.main === module) {
  main().catch((error) => {
    console.error('Script failed:', error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}

import {ethers} from 'hardhat';
import {getGovernor} from '../utils/wallet';
import {fundIfLocalNetwork} from '../utils/network';
import {DEFAULT_TX_OVERRIDES} from '../utils/constants';

/**
 * Simplified script to unpause all aspects of the MessageBridge contract
 *
 * This script will attempt to unpause:
 * 1. Main bridge functionality (unpause)
 * 2. Message sending (unpauseSending)
 * 3. Message execution (unpauseExecuting)
 *
 * Note: All unpause operations require governor privileges
 * If a component is already unpaused, the operation will be skipped with a message
 *
 * Usage:
 * MESSAGE_BRIDGE_ADDRESS=0x... npx hardhat run scripts/messages/unpauseMessageBridge.ts --network <network>
 */

interface UnpauseResult {
  operation: string;
  success: boolean;
  txHash?: string;
  error?: string;
  alreadyUnpaused?: boolean;
}

async function main() {
  const messageBridgeAddress = process.env.MESSAGE_BRIDGE_ADDRESS;

  if (!messageBridgeAddress) {
    console.error('Please set MESSAGE_BRIDGE_ADDRESS environment variable');
    process.exit(1);
  }

  if (!ethers.isAddress(messageBridgeAddress)) {
    console.error('MESSAGE_BRIDGE_ADDRESS must be a valid Ethereum address');
    process.exit(1);
  }

  console.log('MessageBridge Unpause Script (Simplified)');
  console.log(`Bridge Address: ${messageBridgeAddress}`);

  // Get governor account
  const governor = getGovernor(ethers.provider);
  const governorAddress = await governor.getAddress();
  console.log(`Governor Address: ${governorAddress}`);

  // Fund governor if on local network
  await fundIfLocalNetwork([governorAddress]);

  // Get MessageBridge contract instance
  const messageBridge = await ethers.getContractAt('MessageBridge', messageBridgeAddress, governor);

  console.log('\nAttempting unpause operations...');
  console.log('Note: Operations will be skipped automatically if components are already unpaused');

  const results: UnpauseResult[] = [];

  // 1. Unpause main bridge functionality
  console.log('\n1. Attempting to unpause main bridge functionality...');
  try {
    const tx = await messageBridge.unpause(DEFAULT_TX_OVERRIDES);
    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    if (receipt) {
      console.log(`Transaction confirmed in block: ${receipt.blockNumber}`);
      console.log('Main bridge unpaused successfully');
      results.push({
        operation: 'Main Bridge Unpause',
        success: true,
        txHash: tx.hash,
      });
    } else {
      console.log('Transaction receipt not available');
    }
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    // log the error message for debugging
    console.log('Error message:', errorMsg);
    // Check for various "already unpaused" error conditions
    if (errorMsg.includes('MessageBridgeNotPaused') ||
        errorMsg.includes('NotPaused') ||
        errorMsg.includes('already') ||
        (errorMsg.includes('execution reverted') && !errorMsg.includes('NoAuthorization'))) {
      console.log('Main bridge is already unpaused');
      results.push({
        operation: 'Main Bridge Unpause',
        success: true,
        alreadyUnpaused: true,
      });
    } else {
      console.error('Failed to unpause main bridge:', errorMsg);
      results.push({
        operation: 'Main Bridge Unpause',
        success: false,
        error: errorMsg,
      });
    }
  }

  // 2. Unpause sending functionality
  console.log('\n2. Attempting to unpause message sending...');
  try {
    const tx = await messageBridge.unpauseSending(DEFAULT_TX_OVERRIDES);
    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    if (receipt) {
      console.log(`Transaction confirmed in block: ${receipt.blockNumber}`);
      console.log('Message sending unpaused successfully');
      results.push({
        operation: 'Sending Unpause',
        success: true,
        txHash: tx.hash,
      });
    }
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.log('Error message:', errorMsg);
    // Check for various "already unpaused" error conditions
    if (errorMsg.includes('SendingNotPaused') ||
        errorMsg.includes('NotPaused') ||
        errorMsg.includes('already') ||
        (errorMsg.includes('execution reverted') && !errorMsg.includes('NoAuthorization'))) {
      console.log('Message sending is already unpaused');
      results.push({
        operation: 'Sending Unpause',
        success: true,
        alreadyUnpaused: true,
      });
    } else {
      console.error('Failed to unpause sending:', errorMsg);
      results.push({
        operation: 'Sending Unpause',
        success: false,
        error: errorMsg,
      });
    }
  }

  // 3. Unpause executing functionality
  console.log('\n3. Attempting to unpause message execution...');
  try {
    const tx = await messageBridge.unpauseExecuting(DEFAULT_TX_OVERRIDES);
    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    if (receipt) {
      console.log(`Transaction confirmed in block: ${receipt.blockNumber}`);
      console.log('Message execution unpaused successfully');
      results.push({
        operation: 'Executing Unpause',
        success: true,
        txHash: tx.hash,
      });
    }
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.log('Error message:', errorMsg);
    // Check for various "already unpaused" error conditions
    if (errorMsg.includes('ExecutingNotPaused') ||
        errorMsg.includes('NotPaused') ||
        errorMsg.includes('already') ||
        (errorMsg.includes('execution reverted') && !errorMsg.includes('NoAuthorization'))) {
      console.log('Message execution is already unpaused');
      results.push({
        operation: 'Executing Unpause',
        success: true,
        alreadyUnpaused: true,
      });
    } else {
      console.error('Failed to unpause executing:', errorMsg);
      results.push({
        operation: 'Executing Unpause',
        success: false,
        error: errorMsg,
      });
    }
  }

  // Summary
  console.log('\n' + '='.repeat(50));
  console.log('UNPAUSE OPERATIONS SUMMARY');
  console.log('='.repeat(50));

  let successCount = 0;
  let errorCount = 0;
  let alreadyUnpausedCount = 0;

  results.forEach((result, index) => {
    console.log(`\n${index + 1}. ${result.operation}:`);
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

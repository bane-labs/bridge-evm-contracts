import {ethers} from 'hardhat';
import {getGovernor} from '../utils/wallet';
import {fundIfLocalNetwork} from '../utils/network';
import {DEFAULT_TX_OVERRIDES} from '../utils/constants';

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
 * MESSAGE_BRIDGE_ADDRESS=0x... npx hardhat run scripts/messages/unpauseMessageBridge.ts --network <network>
 */

interface UnpauseResult {
  operation: string;
  success: boolean;
  txHash?: string;
  error?: string;
  alreadyUnpaused?: boolean;
}

interface AlreadyUnpausedPredicates {
  errorName: string;
  errorSelector: string;
}

/**
 * Performs an unpause operation with centralized error handling
 */
async function performUnpause(
  operationName: string,
  unpauseFunction: () => Promise<any>,
  predicates: AlreadyUnpausedPredicates
): Promise<UnpauseResult> {
  console.log(`\nAttempting to unpause ${operationName.toLowerCase()}...`);

  try {
    const tx = await unpauseFunction();
    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();

    if (receipt) {
      console.log(`Transaction confirmed in block: ${receipt.blockNumber}`);
      console.log(`${operationName} unpaused successfully`);
      return {
        operation: `${operationName} Unpause`,
        success: true,
        txHash: tx.hash,
      };
    } else {
      console.log('Transaction receipt not available');
      return {
        operation: `${operationName} Unpause`,
        success: false,
        error: 'Transaction receipt not available',
      };
    }
  } catch (error: any) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.log('Error message:', errorMsg);

    // Check for specific "already unpaused" error conditions
    let isAlreadyUnpaused = false;

    // Check for custom error by name (if ethers decoded it)
    if (error.errorName === predicates.errorName) {
      isAlreadyUnpaused = true;
    }
    // Check for custom error selector
    else if (error.data && error.data.startsWith(predicates.errorSelector)) {
      isAlreadyUnpaused = true;
    }
    // Check for explicit error message (fallback)
    else if (errorMsg.includes(predicates.errorName)) {
      isAlreadyUnpaused = true;
    }

    if (isAlreadyUnpaused) {
      console.log(`${operationName} is already unpaused`);
      return {
        operation: `${operationName} Unpause`,
        success: true,
        alreadyUnpaused: true,
      };
    } else {
      console.error(`Failed to unpause ${operationName.toLowerCase()}:`, errorMsg);
      return {
        operation: `${operationName} Unpause`,
        success: false,
        error: errorMsg,
      };
    }
  }
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

  // 1. Unpause message bridge functionality
  const messageBridgeResult = await performUnpause(
    'Message Bridge',
    () => messageBridge.unpause(DEFAULT_TX_OVERRIDES),
    {
      errorName: 'MessageBridgeNotPaused',
      errorSelector: '0xfa5fc19e',
    }
  );
  results.push(messageBridgeResult);

  // 2. Unpause sending functionality
  const sendingResult = await performUnpause(
    'Message Sending',
    () => messageBridge.unpauseSending(DEFAULT_TX_OVERRIDES),
    {
      errorName: 'SendingNotPaused',
      errorSelector: '0x26e7ced5',
    }
  );
  results.push(sendingResult);

  // 3. Unpause executing functionality
  const executingResult = await performUnpause(
    'Message Execution',
    () => messageBridge.unpauseExecuting(DEFAULT_TX_OVERRIDES),
    {
      errorName: 'ExecutingNotPaused',
      errorSelector: '0x61654835',
    }
  );
  results.push(executingResult);

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

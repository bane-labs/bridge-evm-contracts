export interface UnpauseResult {
  operation: string;
  success: boolean;
  txHash?: string;
  error?: string;
  alreadyUnpaused?: boolean;
}

export interface PauseResult {
  operation: string;
  success: boolean;
  txHash?: string;
  error?: string;
  alreadyPaused?: boolean;
}

interface AlreadyUnpausedPredicates {
  errorName: string;
  errorSelector: string;
}

interface AlreadyPausedPredicates {
  errorName: string;
  errorSelector: string;
}

/**
 * Performs an unpause operation with centralized error handling
 */
export async function performUnpause(
  operationName: string,
  isPaused: () => Promise<boolean>,
  unpauseFunction: () => Promise<any>,
  predicates: AlreadyUnpausedPredicates
): Promise<UnpauseResult> {

  if (!(await isPaused())) {
    return {
      operation: `${operationName} Unpause`,
      success: true,
      alreadyUnpaused: true,
    };
  }

  console.log(`\n${operationName} is paused, attempting to unpause...`);

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

/**
 * Performs a pause operation with centralized error handling
 */
export async function performPause(
  operationName: string,
  isPaused: () => Promise<boolean>,
  pauseFunction: () => Promise<any>,
  predicates: AlreadyPausedPredicates
): Promise<PauseResult> {

  if (await isPaused()) {
    return {
      operation: `${operationName} Pause`,
      success: true,
      alreadyPaused: true,
    };
  }

  console.log(`\n${operationName} is not paused, attempting to pause...`);

  try {
    const tx = await pauseFunction();
    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();

    if (receipt) {
      console.log(`Transaction confirmed in block: ${receipt.blockNumber}`);
      console.log(`${operationName} paused successfully`);
      return {
        operation: `${operationName} Pause`,
        success: true,
        txHash: tx.hash,
      };
    } else {
      console.log('Transaction receipt not available');
      return {
        operation: `${operationName} Pause`,
        success: false,
        error: 'Transaction receipt not available',
      };
    }
  } catch (error: any) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.log('Error message:', errorMsg);

    // Check for specific "already paused" error conditions
    let isAlreadyPaused = false;

    // Check for custom error by name (if ethers decoded it)
    if (error.errorName === predicates.errorName) {
      isAlreadyPaused = true;
    }
    // Check for custom error selector
    else if (error.data && error.data.startsWith(predicates.errorSelector)) {
      isAlreadyPaused = true;
    }
    // Check for explicit error message (fallback)
    else if (errorMsg.includes(predicates.errorName)) {
      isAlreadyPaused = true;
    }

    if (isAlreadyPaused) {
      console.log(`${operationName} is already paused`);
      return {
        operation: `${operationName} Pause`,
        success: true,
        alreadyPaused: true,
      };
    } else {
      console.error(`Failed to pause ${operationName.toLowerCase()}:`, errorMsg);
      return {
        operation: `${operationName} Pause`,
        success: false,
        error: errorMsg,
      };
    }
  }
}

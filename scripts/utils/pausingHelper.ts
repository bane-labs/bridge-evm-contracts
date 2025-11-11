export interface PausingActionResult {
  operation: string;
  success: boolean;
  txHash?: string;
  error?: string;
  actionRedundant?: boolean;
}

interface ErrorPredicate {
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
  predicate: ErrorPredicate
): Promise<PausingActionResult> {
  return await performPausingAction(
    "unpause",
    operationName,
    isPaused,
    unpauseFunction,
    predicate
  );
}

/**
 * Performs a pause operation with centralized error handling
 */
export async function performPause(
  operationName: string,
  isPaused: () => Promise<boolean>,
  pauseFunction: () => Promise<any>,
  predicate: ErrorPredicate
): Promise<PausingActionResult> {
  return await performPausingAction(
    "pause",
    operationName,
    isPaused,
    pauseFunction,
    predicate
  );
}

async function performPausingAction(
  pausingAction: "pause" | "unpause",
  operationName: string,
  isPaused: () => Promise<boolean>,
  pausingFunction: () => Promise<any>,
  predicate: ErrorPredicate
): Promise<PausingActionResult> {
  const pauseName = pausingAction === "pause" ? "Pause" : "Unpause";
  const isCurrentlyPaused = await isPaused()

  if (isCurrentlyPaused) {
    console.log(`${operationName} is currently paused.`);
    if (pausingAction === "pause") {
      console.log(`No action needed; ${operationName} is already paused.`);
      return {
        operation: `${operationName} Pause`,
        success: true,
        actionRedundant: true,
      };
    } else {
      console.log(`${operationName} is paused, proceeding to unpause.`);
    }
  } else {
    console.log(`${operationName} is currently not paused.`);
    if (pausingAction === "unpause") {
      console.log(`No action needed; ${operationName} is already unpaused.`);
      return {
        operation: `${operationName} Unpause`,
        success: true,
        actionRedundant: true,
      };
    } else {
      console.log(`${operationName} is not paused, proceeding to pause.`);
    }
  }

  try {
    const tx = await pausingFunction();
    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();

    if (receipt) {
      console.log(`Transaction confirmed in block: ${receipt.blockNumber}`);
      console.log(`${operationName} ${pauseName} successfully`);
      return {
        operation: `${operationName} ${pauseName}`,
        success: true,
        txHash: tx.hash,
      };
    } else {
      console.log('Transaction receipt not available');
      return {
        operation: `${operationName} ${pauseName}`,
        success: false,
        error: 'Transaction receipt not available',
      };
    }
  } catch (error: any) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.log('Error message:', errorMsg);

    // Check for specific error predicates
    let predicateMatchFound = false;

    // Check for custom error by name (if ethers decoded it)
    if (error.errorName === predicate.errorName) {
      predicateMatchFound = true;
    }
    // Check for custom error selector
    else if (error.data && error.data.startsWith(predicate.errorSelector)) {
      predicateMatchFound = true;
    }
    // Check for explicit error message (fallback)
    else if (errorMsg.includes(predicate.errorName)) {
      predicateMatchFound = true;
    }

    if (predicateMatchFound) {
      console.log(`${operationName} is already ${pausingAction}d`);
      return {
        operation: `${operationName} ${pauseName}`,
        success: true,
        actionRedundant: true,
      };
    } else {
      console.error(`Failed to ${pausingAction} ${operationName.toLowerCase()}:`, errorMsg);
      return {
        operation: `${operationName} ${pauseName}`,
        success: false,
        error: errorMsg,
      };
    }
  }
}

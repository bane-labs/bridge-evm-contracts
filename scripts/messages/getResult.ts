import { getMessageBridgeFromEnv } from '../utils/addresses';
import { MessageBridge } from '../../typechain-types';

async function getExecutionResult(messageBridge: MessageBridge, nonce: number): Promise<void> {
  try {
    const state = await messageBridge.getExecutableState(nonce);
    // log both fields of the state here on one line, not just the executed field
    const expirationDate = new Date(Number(state.expirationTimestamp) * 1000);
    console.log(`Executable state - Executed: ${state.executed}, Expiration: ${expirationDate}`);


    const { success, returnData } = await messageBridge.getEvmExecutionResult(nonce);
    console.log(`EVM execution result - Success: ${success}, Data: ${returnData}`);
  } catch (error) {
    console.log(`EVM execution result not found for nonce ${nonce}`);
  }

  const neoNonce = await messageBridge.getNeoExecutionResultNonce(nonce);
  const neoResult = await messageBridge.getNeoExecutionResult(neoNonce);
  console.log(`NeoN3 execution result (nonce ${neoNonce}): ${neoResult}`);
}

async function main(): Promise<void> {
  const envNonce = process.env.NONCE;
  if (!envNonce) {
    throw new Error('Please set the NONCE environment variable');
  }

  const nonce = parseInt(envNonce, 10);
  if (isNaN(nonce)) {
    throw new Error('NONCE must be a valid number');
  }

  const messageBridge = await getMessageBridgeFromEnv();
  await getExecutionResult(messageBridge, nonce);
}

main().catch((error) => {
  console.error('Error:', error.message);
  process.exitCode = 1;
});

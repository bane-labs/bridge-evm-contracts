const {getMessageBridgeFromEnv} = require('../utils/addresses');

async function getExecutionResult(messageBridge, nonce) {
  try {
    const {success, returnData} = await messageBridge.getEvmExecutionResult(nonce);
    console.log('EVM Execution result:');
    console.log(success);
    console.log(returnData);
  } catch (e) {
    console.log('EVM Execution result not found for nonce', nonce);
  }
  const neoNonce = await messageBridge.getNeoExecutionResultNonce(nonce);
  console.log('Corresponding NeoN3 execution result nonce:', neoNonce.toString());
  const neoResult = await messageBridge.getNeoExecutionResult(neoNonce);
  console.log('NeoN3 Execution result:');
  console.log(neoResult);
}

async function main() {
  const envNonce = process.env.NONCE || (() => {
    throw new Error('Please set the NONCE environment variable');
  })();
  const nonce = parseInt(envNonce);
  const messageBridge = await getMessageBridgeFromEnv();
  await getExecutionResult(messageBridge, nonce);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

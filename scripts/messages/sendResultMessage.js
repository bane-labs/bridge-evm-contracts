const {ethers} = require('hardhat');
const {fundIfLocalNetwork} = require('../utils/network');
const {getMessageBridgeFromEnv} = require('../utils/addresses');
const {getOwner, getDeployer} = require('../utils/wallet');
const {DEFAULT_TX_OVERRIDES} = require('../utils/constants');

async function sendTestMessageResult(messageBridge) {
  await fundIfLocalNetwork([sender.address]);
  const sender = getDeployer(ethers.provider);
  const envNonce = process.env.NONCE || (() => { throw new Error("Please set the NONCE environment variable"); })();
  const nonce = parseInt(envNonce);

  // const sendingFee = ethers.parseEther("0.1");
  const fee = await messageBridge.sendingFee();
  console.log('Current sending fee:', ethers.formatEther(fee), 'ETH');
  let result = await messageBridge.getEvmExecutionResult(nonce);
  console.log('Current execution result for nonce', nonce, ':', result);

  // Get and print the EVM to NeoN3 state root
  const evmToNeoState = await messageBridge.evmToNeoState();
  console.log('EVM to NeoN3 state root:', evmToNeoState.root);
  console.log('EVM to NeoN3 state nonce:', evmToNeoState.nonce.toString());
  // Get and print the NeoN3 to EVM state root
  const neoToEvmState = await messageBridge.neoToEvmState();
  console.log('NeoN3 to EVM state root:', neoToEvmState.root);
  console.log('NeoN3 to EVM state nonce:', neoToEvmState.nonce.toString());

  let txr = await messageBridge.connect(sender).sendResultMessage(nonce, {value: fee, ...DEFAULT_TX_OVERRIDES});

  const response = await txr.wait();
  console.log("Result message sent. Transaction hash:", txr.hash);
  console.log("Transaction mined. Status:", response.status);
}

async function main() {
  const messageBridge = await getMessageBridgeFromEnv();
  await sendTestMessageResult(messageBridge);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

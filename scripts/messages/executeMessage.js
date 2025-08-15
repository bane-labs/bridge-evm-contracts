const { ethers } = require("hardhat");
const { fundIfLocalNetwork } = require("../utils/network");
const { getMessageBridgeFromEnv } = require("../utils/addresses");
const { getOwner } = require("../utils/wallet");
const { DEFAULT_TX_OVERRIDES } = require("../utils/constants");

async function executeMessage(messageBridge, sender, nonce) {
  await fundIfLocalNetwork([sender.address]);
  await messageBridge.connect(sender).executeMessage(nonce, DEFAULT_TX_OVERRIDES);
}

async function main() {
  const sender = getOwner(ethers.provider);
  const nonce = 1;
  const messageBridge = await getMessageBridgeFromEnv();
  await executeMessage(messageBridge, sender, nonce);
}

async function decodeBalanceResult(resultData) {
  // Decode the uint256 balance result
  const abiCoder = new ethers.AbiCoder();
  const balance = abiCoder.decode(["uint256"], resultData)[0];
  return balance;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

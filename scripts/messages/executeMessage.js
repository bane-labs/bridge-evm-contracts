const { ethers } = require("hardhat");
const { fundIfLocalNetwork } = require("../utils/network");
const { getMessageBridgeFromEnv } = require("../utils/addresses");
const { getOwner } = require("../utils/wallet");
const { DEFAULT_TX_OVERRIDES } = require("../utils/constants");

async function executeMessage(messageBridge, sender, nonce) {
  await fundIfLocalNetwork([sender.address]);
  let message = await messageBridge.connect(sender).getEvmMessage(nonce);
  console.log("Executing message:", message);
  const tx = await messageBridge
    .connect(sender)
    .executeMessage(nonce, DEFAULT_TX_OVERRIDES);
  console.log("Transaction sent. Hash:", tx.hash);
  const receipt = await tx.wait();
  console.log("Transaction mined. Status:", receipt.status);
}

async function main() {
  const sender = getOwner(ethers.provider);
  const envNonce = process.env.NONCE || (() => { throw new Error("Please set the NONCE environment variable"); })();
  const nonce = parseInt(envNonce);
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

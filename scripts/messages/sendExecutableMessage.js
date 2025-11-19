const { ethers } = require("hardhat");
const { fundIfLocalNetwork } = require("../utils/network");
const { getMessageBridgeFromEnv } = require("../utils/addresses");
const { getOwner } = require("../utils/wallet");
const { DEFAULT_TX_OVERRIDES } = require("../utils/constants");

async function sendExecutableMessage(messageBridge, sender, rawMsg) {
  await fundIfLocalNetwork([sender.address]);
  const storeResult = true;
  const feeSlot = "0xd6595d2280e6cba67baf67ff997445e733b244161e59228efeb7032069381107";
  const feeSlotValue = await ethers.provider.getStorage(await messageBridge.getAddress(), feeSlot);

  console.log("Fee slot value:", feeSlotValue);
  console.log(feeSlotValue);
  const sendingFee = ethers.parseEther("0.1");
  const result = await messageBridge.connect(sender).sendExecutableMessage(rawMsg, storeResult, {value: sendingFee}, DEFAULT_TX_OVERRIDES);
  console.log("Message sent successfully:", result.hash);
  console.log("Result:");
  console.log(result);
}

async function main() {
  const sender = getOwner(ethers.provider);
  const messageBridge = await getMessageBridgeFromEnv();
  const rawMsg = "0x40042814f563ea40bc283d4d0e05c48ea305b3f2a07340ef280962616c616e63654f6621010540012814cdabefcdabefcdabefcdabefcdabefcdabefcdab";
  await sendExecutableMessage(messageBridge, sender, rawMsg);
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

const { ethers } = require("hardhat");
const { fundIfLocalNetwork } = require("../utils/network");
const { getOwner, getDeployer } = require("../utils/wallet");
const { DEFAULT_TX_OVERRIDES } = require("../utils/constants");

async function storeTestMessage() {
  const sender = getOwner(ethers.provider);
  await fundIfLocalNetwork([sender.address]);

  const nonce = 1;

  // Define the Neo token contract address on EVM and target address
  const neoTokenContractAddress = "0x7332654b3601323053873B5f9fD5cA9D2991CA6a"; // Neo token address on Neo X Testnet
  const targetAddress = (await getDeployer(ethers.provider)).address; // Address to check the balance for

  const erc20Interface = new ethers.Interface([
    "function balanceOf(address account) view returns (uint256)"
  ]);

  const callData = erc20Interface.encodeFunctionData("balanceOf", [targetAddress]);
  console.log("Encoded balanceOf callData:", callData);

  const evmCall = {
    target: neoTokenContractAddress,    // Target EVM Neo token contract
    allowFailure: false,                // Don't allow failure
    value: 0,                           // No gas value needed for the call
    callData: callData                  // Encoded balanceOf(address) call data
  };

  const metadata = {
    msgType: 0,
    timestamp: Math.floor(Date.now() / 1000), // Current timestamp in seconds (as integer)
    sender: sender.address,
    storeResult: true
  }

  const callStructAbi = [
    "tuple(address target, bool allowFailure, uint256 value, bytes callData)"
  ];
  const metadataStructAbi = [
    "tuple(uint8 msgType, uint64 timestamp, address sender, bool storeResult)"
  ];
  const abiCoder = new ethers.AbiCoder();
  const serializedMessage = abiCoder.encode(callStructAbi, [evmCall]);
  const serializedMetadata = abiCoder.encode(metadataStructAbi, [metadata]);

  const messageData = { nonce, encodedMetadata: serializedMetadata, message: serializedMessage };
  await messageBridge.storeSingleMessage(messageData, DEFAULT_TX_OVERRIDES);

  console.log("Message executable state:");
  console.log(await messageBridge.getExecutableState(nonce));

  console.log("Message stored:");
  console.log(await messageBridge.n3ToEvmMessages(nonce));
}

async function main() {
  await storeTestMessage();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

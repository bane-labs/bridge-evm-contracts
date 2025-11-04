import {encodeEvmCall} from './messageBridgeUtils';
import {ethers} from 'hardhat';

// ERC20 balanceOf(address) function signature
const functionSignature = "balanceOf(address)";
const address = process.env.ADDRESS || "0xb156115f737be58a9115febe08dc474c8117aebd";
const erc20Target = process.env.ERC20_TARGET || "0x05fd43b3eFcb4ff1CA08229cAEcf67Bc21D0C0a3";
const value = BigInt(process.env.VALUE || "0");

const iface = new ethers.Interface([`function ${functionSignature}`]);
const encodedCallData = iface.encodeFunctionData(functionSignature, [address]);
console.log("Encoded callData:", encodedCallData);

// Encode as AMBTypes.Call using MessageBridgeUtils
const encodedEvmCall = encodeEvmCall(erc20Target, true, value, encodedCallData);
console.log("Encoded AMBTypes.Call:", encodedEvmCall);

async function callViewFunction() {
  const provider = ethers.provider;
  const callResult = await provider.call({
    to: erc20Target,
    data: encodedCallData
  });
  // Parse the returned hex as uint256
  const value = BigInt(callResult);
  console.log("Balance value:", value.toString());
}

async function isContract(address: string, provider: any): Promise<boolean> {
  const code = await provider.getCode(address);
  return code && code !== "0x";
}

callViewFunction().catch(console.error);
isContract(erc20Target, ethers.provider).catch(console.error);

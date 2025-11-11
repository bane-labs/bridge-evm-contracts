import { encodeEvmCall } from './messageBridgeUtils';
import { ethers } from 'hardhat';

// ERC20 balanceOf(address) function signature
const functionSignature = "balanceOf(address)";
const address = process.env.ADDRESS || "0x1212000000000000000000000000000000000004";
const erc20Target = process.env.ERC20_TARGET || "0xab0a26b8d903f36acb4bf9663f8d2de0672433cd";
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

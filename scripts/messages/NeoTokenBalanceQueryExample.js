const { ethers } = require('ethers');

export function getEncodedMessage(tokenAddress, targetAddress) {
    // Encode the balanceOf call using ethers
    const erc20Interface = new ethers.Interface(["function balanceOf(address account) view returns (uint256)"]);
    const callData = erc20Interface.encodeFunctionData("balanceOf", [targetAddress]);

    // Create the Call structure
    const evmCall = {
        target: tokenAddress,
        allowFailure: false,
        value: 0,
        callData: callData
    };

    // Serialize the Call structure
    const callStructAbi = ["tuple(address target, bool allowFailure, uint256 value, bytes callData)"];
    const abiCoder = new ethers.AbiCoder();
    const serializedMessage = abiCoder.encode(callStructAbi, [evmCall]);

    return {
        serializedMessage: serializedMessage,
        callData: callData,
        evmCall: evmCall
    };
}

export function decodeBalanceResult(resultData) {
    // Decode the uint256 balance result
    const abiCoder = new ethers.AbiCoder();
    const balance = abiCoder.decode(["uint256"], resultData)[0];
    return balance;
}

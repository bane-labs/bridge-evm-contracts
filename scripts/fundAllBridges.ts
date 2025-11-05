import { ethers } from "hardhat";
import { getBridgeFromEnv } from "./utils/addresses";
import {getDeployer, getOwner} from './utils/wallet';
import { fundAddress } from "./utils/funding";

async function sendETHToBridge() {
    // Get the owner wallet
    const owner = getOwner(ethers.provider);
    console.log(`Using owner wallet: ${owner.address}`);

    // Get the bridge contract from environment variable
    const bridge = await getBridgeFromEnv(ethers.provider);
    const bridgeAddress = await bridge.getAddress();
    console.log(`Bridge contract address: ${bridgeAddress}`);

    // Amount to send (can be customized via env variable or hardcoded)
    const amount = process.env.ETH_AMOUNT ? ethers.parseEther(process.env.ETH_AMOUNT) : ethers.parseEther("0.01");
    console.log(`Sending ${ethers.formatEther(amount)} ETH to bridge...`);

    // Send ETH to the bridge contract
    await fundAddress(owner, bridgeAddress, amount);

    console.log("ETH transfer completed successfully!");
}

async function sendERC20ToBridge() {
    // Get the token address from environment variable
    const tokenAddress = process.env.TOKEN_ADDRESS;
    if (!tokenAddress) {
        throw new Error("TOKEN_ADDRESS environment variable is required for ERC20 transfer");
    }

    // Get the amount from environment variable
    const tokenAmount = process.env.TOKEN_AMOUNT;
    if (!tokenAmount) {
        throw new Error("TOKEN_AMOUNT environment variable is required for ERC20 transfer");
    }

    // Get the deployer wallet
    const deployer = getDeployer(ethers.provider);
    console.log(`Using owner wallet: ${deployer.address}`);

    // Get the bridge contract from environment variable
    const bridge = await getBridgeFromEnv(ethers.provider);
    const bridgeAddress = await bridge.getAddress();
    console.log(`Bridge contract address: ${bridgeAddress}`);

    // Get the ERC20 token contract
    const token = await ethers.getContractAt("ERC20", tokenAddress);
    const decimals = await token.decimals();
    const amount = ethers.parseUnits(tokenAmount, decimals);

    console.log(`Token address: ${tokenAddress}`);
    console.log(`Sending ${tokenAmount} tokens (${amount} wei) to bridge...`);

    // Transfer tokens to bridge
    console.log("Transferring tokens to bridge...");
    const transferTx = await token.connect(deployer).transfer(bridgeAddress, amount);
    await transferTx.wait();

    console.log("ERC20 transfer completed successfully!");
}

async function main() {
        await sendETHToBridge();
        await sendERC20ToBridge();
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

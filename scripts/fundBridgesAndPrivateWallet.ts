import { ethers } from "hardhat";
import { getBridgeFromEnv } from "./utils/addresses";
import {getDeployer, getOwner, getPersonalWallet} from './utils/wallet';
import { fundAddress } from "./utils/funding";

async function sendETHToBridge() {
    // Only the account that has the FUNDER role in the bridge can send ETH to it
    // This function expects the owner to have the FUNDER role (this script is only intended to be used in test envs).
    const owner = getOwner(ethers.provider);
    console.log(`Using owner wallet: ${owner.address}`);

    // Get the bridge contract from environment variable
    const bridge = await getBridgeFromEnv(ethers.provider);
    const bridgeAddress = await bridge.getAddress();
    console.log(`Bridge contract address: ${bridgeAddress}`);

    // Amount to send (can be customized via env variable or hardcoded)
    const amount = process.env.ETH_AMOUNT ?
        ethers.parseEther(process.env.ETH_AMOUNT) :
        ethers.parseEther("10"); // Default to 10 ETH
    console.log(`Sending ${ethers.formatEther(amount)} ETH to bridge...`);

    // Send ETH to the bridge contract
    await fundAddress(owner, bridgeAddress, amount);

    console.log("ETH transfer completed successfully!");
}

async function sendERC20ToBridgeAndPrivateWallet() {
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

    // Get the deployer wallet (sender) and personal wallet (receiver for 10%)
    const deployer = getDeployer(ethers.provider);
    const personalWallet = getPersonalWallet( ethers.provider);
    console.log(`Using deployer wallet: ${deployer.address}`);
    console.log(`Personal wallet address: ${personalWallet.address}`);

    // Get the bridge contract from environment variable
    const bridge = await getBridgeFromEnv(ethers.provider);
    const bridgeAddress = await bridge.getAddress();
    console.log(`Bridge contract address: ${bridgeAddress}`);

    // Get the ERC20 token contract
    const token = await ethers.getContractAt("ERC20", tokenAddress);
    const decimals = await token.decimals();
    const totalAmount = ethers.parseUnits(tokenAmount, decimals);

    // Calculate amounts: 90% to bridge, 10% to personal wallet
    const bridgeAmount = (totalAmount * 90n) / 100n;
    const personalAmount = totalAmount - bridgeAmount;

    console.log(`Token address: ${tokenAddress}`);
    console.log(`Total tokens to distribute: ${tokenAmount} (${totalAmount} wei)`);
    console.log(`Sending ${ethers.formatUnits(bridgeAmount, decimals)} tokens (90%) to bridge...`);
    console.log(`Sending ${ethers.formatUnits(personalAmount, decimals)} tokens (10%) to personal wallet...`);

    // Transfer 90% of tokens to bridge
    console.log("Transferring tokens to bridge...");
    const transferToBridgeTx = await token.connect(deployer).transfer(bridgeAddress, bridgeAmount);
    await transferToBridgeTx.wait();

    // Transfer 10% of tokens to personal wallet
    console.log("Transferring tokens to personal wallet...");
    const transferToPersonalTx = await token.connect(deployer).transfer(personalWallet.address, personalAmount);
    await transferToPersonalTx.wait();

    console.log("ERC20 transfers completed successfully!");
    console.log(`Bridge received: ${ethers.formatUnits(bridgeAmount, decimals)} tokens`);
    console.log(`Personal wallet received: ${ethers.formatUnits(personalAmount, decimals)} tokens`);
}

async function main() {
        await sendETHToBridge();
        await sendERC20ToBridgeAndPrivateWallet();
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

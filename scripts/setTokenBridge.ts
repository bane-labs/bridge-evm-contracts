import { ethers } from "hardhat";
import { getBridgeFromEnv, NEOX_TOKEN_ADDRESS } from "./utils/addresses";
import { fundIfLocalNetwork } from "./utils/network";
import { getGovernor } from "./utils/wallet";

async function main() {
    // Get the governor wallet to call the setter functions
    const governor = getGovernor(ethers.provider);
    await fundIfLocalNetwork([governor.address]);
    
    // Get the bridge contract
    const bridge = await getBridgeFromEnv(ethers.provider);
    
    // Token address - can be from env or passed as parameter
    const tokenAddress = process.env.TOKEN_ADDRESS || NEOX_TOKEN_ADDRESS;
    if (!tokenAddress) {
        throw new Error("TOKEN_ADDRESS is required. Set TOKEN_ADDRESS environment variable or update NEOX_TOKEN_ADDRESS.");
    }
    
    console.log(`Setting token bridge parameters for token: ${tokenAddress}`);
    console.log(`Using governor address: ${governor.address}`);
    console.log(`Bridge address: ${await bridge.getAddress()}`);
    
    // Token bridge configuration parameters
    const withdrawalFee = process.env.TOKEN_WITHDRAWAL_FEE || ethers.parseEther("0.001"); // 0.001 ETH default
    const minWithdrawalAmount = process.env.MIN_TOKEN_WITHDRAWAL || ethers.parseEther("1"); // 1 token default
    const maxWithdrawalAmount = process.env.MAX_TOKEN_WITHDRAWAL || ethers.parseEther("1000"); // 1000 tokens default
    const maxDeposits = process.env.MAX_TOKEN_DEPOSITS || "100"; // 100 deposits default
    
    try {
        // Set token withdrawal fee
        console.log(`Setting token withdrawal fee to: ${ethers.formatEther(withdrawalFee)} ETH`);
        const feesTx = await bridge.connect(governor).setTokenWithdrawalFee(
            [tokenAddress],
            [withdrawalFee]
        );
        await feesTx.wait();
        console.log(`Token withdrawal fee set. TX: ${feesTx.hash}`);
        
        // Set minimum token withdrawal amount
        console.log(`Setting minimum token withdrawal amount to: ${ethers.formatEther(minWithdrawalAmount)} tokens`);
        const minTx = await bridge.connect(governor).setMinTokenWithdrawalAmount(
            [tokenAddress],
            [minWithdrawalAmount]
        );
        await minTx.wait();
        console.log(`Minimum token withdrawal amount set. TX: ${minTx.hash}`);
        
        // Set maximum token withdrawal amount
        console.log(`Setting maximum token withdrawal amount to: ${ethers.formatEther(maxWithdrawalAmount)} tokens`);
        const maxTx = await bridge.connect(governor).setMaxTokenWithdrawalAmount(
            [tokenAddress],
            [maxWithdrawalAmount]
        );
        await maxTx.wait();
        console.log(`Maximum token withdrawal amount set. TX: ${maxTx.hash}`);
        
        // Set maximum token deposits
        console.log(`Setting maximum token deposits to: ${maxDeposits}`);
        const depositsTx = await bridge.connect(governor).setMaxTokenDeposits(
            [tokenAddress],
            [maxDeposits]
        );
        await depositsTx.wait();
        console.log(`Maximum token deposits set. TX: ${depositsTx.hash}`);
        
        console.log("\nToken bridge configuration completed successfully!");
        
    } catch (error) {
        console.error("Error setting token bridge parameters:", error);
        throw error;
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

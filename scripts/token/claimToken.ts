import { ethers } from "hardhat";
import { MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "../utils/constants";
import { getPersonalWallet } from "../utils/wallet";

async function main() {
    const bridgeAddress = process.env.BRIDGE_ADDRESS!;
    const nonce = process.env.NONCE!;
    const neoXTokenAddress = process.env.NEOX_TOKEN_ADDRESS!;

    if (!bridgeAddress) {
        throw new Error('BRIDGE_ADDRESS environment variable is required');
    }

    if (!nonce) {
        throw new Error('NONCE environment variable is required');
    }

    if (!neoXTokenAddress) {
        throw new Error('NEOX_TOKEN_ADDRESS environment variable is required');
    }

    if (!ethers.isAddress(neoXTokenAddress)) {
        throw new Error('NEOX_TOKEN_ADDRESS must be a valid address');
    }

    if (isNaN(Number(nonce))) {
        throw new Error('NONCE must be a valid number');
    }

    const claimer = getPersonalWallet(ethers.provider);
    const bridge = await ethers.getContractAt('TestBridge', bridgeAddress, claimer);
    const token = await ethers.getContractAt('IERC20', neoXTokenAddress, claimer);

    console.log(`Attempting to claim tokens for:`);
    console.log(`- Token Address: ${neoXTokenAddress}`);
    console.log(`- Nonce: ${nonce}`);
    console.log(`- Claimer Address: ${claimer.address}`);
    console.log(`- Bridge Address: ${bridgeAddress}`);

    try {
        // Read the token bridge deposit state
        console.log('\n=== Token Bridge Deposit State ===');
        const tokenBridge = await bridge.tokenBridges(neoXTokenAddress);
        console.log(`Token: ${neoXTokenAddress}`);
        console.log(`Current deposit nonce: ${tokenBridge.depositState.nonce}`);
        console.log(`Current deposit root: ${tokenBridge.depositState.root}`);
        console.log(`Bridge paused: ${tokenBridge.paused}`);
        console.log(`Fee: ${ethers.formatEther(tokenBridge.config.fee)} ETH`);

        // Check if token is registered
        console.log('\n=== Token Registration Check ===');
        const tokenConfig = await bridge.getTokenConfig(neoXTokenAddress);
        console.log(`Token is registered. Fee: ${tokenConfig.fee}`);

        // Check if claimable exists before attempting to claim
        console.log('\n=== Checking Claimable ===');
        const claimable = await bridge.tokenClaimables(neoXTokenAddress, nonce);
        if (claimable.amount === 0n || claimable.to === "0x0000000000000000000000000000000000000000") {
            console.error(`No claimable found for token ${neoXTokenAddress} and nonce ${nonce}, or it has already been claimed.`);
            process.exit(1);
        }

        console.log(`Found claimable: ${ethers.formatEther(claimable.amount)} tokens for address: ${claimable.to}`);

        const claimTx = await bridge.connect(claimer).claimToken(neoXTokenAddress, nonce, {
            maxFeePerGas: MAX_FEE_PER_GAS,
            maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS
        });

        const receipt = await claimTx.wait();
        console.log("Token Claim Transaction successful!");
        console.log("Transaction Hash:", receipt?.hash);
        console.log("Gas Used:", receipt?.gasUsed?.toString());

        // Get the token balance of the claimer to show the result
        const balance = await token.balanceOf(claimer.address);
        console.log(`Claimer token balance after claim: ${ethers.formatEther(balance)} tokens`);

    } catch (error: any) {
        console.error("Claim failed:", error.message);

        if (error.message.includes("NonexistentClaimable")) {
            console.error(`No claimable found for token ${neoXTokenAddress} and nonce ${nonce}, or it has already been claimed.`);
        } else if (error.message.includes("TokenNotRegistered")) {
            console.error(`Token ${neoXTokenAddress} is not registered on the bridge.`);
        } else if (error.message.includes("TokenBridgePaused")) {
            console.error(`Token bridge for ${neoXTokenAddress} is currently paused.`);
        } else if (error.message.includes("ERC20InsufficientBalance")) {
            console.error("Bridge contract has insufficient token balance for this claim.");
        } else {
            console.error("Unknown error occurred during claim.");
        }
        process.exitCode = 1;
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

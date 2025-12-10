import { ethers } from "hardhat";
import { MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "../utils/constants";
import { getPersonalWallet } from "../utils/wallet";

async function main() {
    const bridgeAddress = process.env.BRIDGE_ADDRESS!;
    const nonce = process.env.NONCE!;

    if (!bridgeAddress) {
        throw new Error('BRIDGE_ADDRESS environment variable is required');
    }

    if (!nonce) {
        throw new Error('NONCE environment variable is required');
    }

    if (isNaN(Number(nonce))) {
        throw new Error('NONCE must be a valid number');
    }

    const claimer = getPersonalWallet(ethers.provider);
    const bridge = await ethers.getContractAt('TestBridge', bridgeAddress, claimer);

    console.log(`Attempting to claim native tokens for nonce: ${nonce}`);
    console.log(`Using claimer address: ${claimer.address}`);
    console.log(`Bridge address: ${bridgeAddress}`);

    try {
        // Read the native bridge deposit state
        console.log('\n=== Native Bridge Deposit State ===');
        const nativeBridge = await bridge.nativeBridge();
        console.log(`Current deposit nonce: ${nativeBridge.depositState.nonce}`);
        console.log(`Current deposit root: ${nativeBridge.depositState.root}`);

        // Check if claimable exists before attempting to claim
        console.log('\n=== Checking Claimable ===');
        const claimable = await bridge.claimableNative(nonce);
        if (claimable.amount === 0n || claimable.to === "0x0000000000000000000000000000000000000000") {
            console.error(`No claimable found for nonce ${nonce}, or it has already been claimed.`);
            process.exit(1);
        }

        console.log(`Found claimable: ${ethers.formatEther(claimable.amount)} ETH for address: ${claimable.to}`);

        const claimTx = await bridge.connect(claimer).claimNative(nonce, {
            maxFeePerGas: MAX_FEE_PER_GAS,
            maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS
        });

        const receipt = await claimTx.wait();
        console.log("Native Claim Transaction successful!");
        console.log("Transaction Hash:", receipt?.hash);
        console.log("Gas Used:", receipt?.gasUsed?.toString());
    } catch (error: any) {
        console.error("Claim failed:", error.message);

        if (error.message.includes("NonexistentClaimable")) {
            console.error(`No claimable found for nonce ${nonce}, or it has already been claimed.`);
        } else if (error.message.includes("TransferFailed")) {
            console.error("Transfer of native tokens failed. The recipient address may be invalid.");
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

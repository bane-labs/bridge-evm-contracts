import { ethers } from "hardhat";
import { getBridgeFromEnv } from "./utils/addresses";
import { fundIfLocalNetwork } from "./utils/network";
import { getGovernor } from "./utils/wallet";

async function main() {
    // Get the governor wallet to call the setter functions
    const governor = getGovernor(ethers.provider);
    await fundIfLocalNetwork([governor.address]);

    // Get the bridge contract
    const bridge = await getBridgeFromEnv(ethers.provider);

    console.log(`Setting native bridge parameters`);
    console.log(`Using governor address: ${governor.address}`);
    console.log(`Bridge address: ${await bridge.getAddress()}`);

    // Check if native bridge is already set
    const isNativeBridgeSet = await bridge.nativeBridgeIsSet();

    if (isNativeBridgeSet) {
        console.log("Native bridge is already configured. Using individual setters for updates...");

        // Native bridge configuration parameters for updates
        const withdrawalFee = process.env.NATIVE_WITHDRAWAL_FEE || ethers.parseEther("0.001"); // 0.001 ETH default
        const minWithdrawalAmount = process.env.MIN_NATIVE_WITHDRAWAL || ethers.parseEther("0.1"); // 0.1 ETH default
        const maxWithdrawalAmount = process.env.MAX_NATIVE_WITHDRAWAL || ethers.parseEther("100"); // 100 ETH default
        const maxDeposits = process.env.MAX_NATIVE_DEPOSITS || "100"; // 100 deposits default

        try {
            // Update native withdrawal fee
            console.log(`Setting native withdrawal fee to: ${ethers.formatEther(withdrawalFee)} ETH`);
            const feesTx = await bridge.connect(governor).setNativeWithdrawalFee(withdrawalFee);
            await feesTx.wait();
            console.log(`Native withdrawal fee updated. TX: ${feesTx.hash}`);

            // Update minimum native withdrawal amount
            console.log(`Setting minimum native withdrawal amount to: ${ethers.formatEther(minWithdrawalAmount)} ETH`);
            const minTx = await bridge.connect(governor).setMinNativeWithdrawalAmount(minWithdrawalAmount);
            await minTx.wait();
            console.log(`Minimum native withdrawal amount updated. TX: ${minTx.hash}`);

            // Update maximum native withdrawal amount
            console.log(`Setting maximum native withdrawal amount to: ${ethers.formatEther(maxWithdrawalAmount)} ETH`);
            const maxTx = await bridge.connect(governor).setMaxNativeWithdrawalAmount(maxWithdrawalAmount);
            await maxTx.wait();
            console.log(`Maximum native withdrawal amount updated. TX: ${maxTx.hash}`);

            // Update maximum native deposits
            console.log(`Setting maximum native deposits to: ${maxDeposits}`);
            const depositsTx = await bridge.connect(governor).setMaxNativeDeposits(maxDeposits);
            await depositsTx.wait();
            console.log(`Maximum native deposits updated. TX: ${depositsTx.hash}`);

        } catch (error) {
            console.error("Error updating native bridge parameters:", error);
            throw error;
        }

    } else {
        console.log("Native bridge not yet configured. Setting up initial configuration...");

        // Native bridge initial configuration parameters
        const withdrawalFee = process.env.NATIVE_WITHDRAWAL_FEE || ethers.parseEther("0.001"); // 0.001 ETH default
        const minWithdrawalAmount = process.env.MIN_NATIVE_WITHDRAWAL || ethers.parseEther("0.1"); // 0.1 ETH default
        const maxWithdrawalAmount = process.env.MAX_NATIVE_WITHDRAWAL || ethers.parseEther("100"); // 100 ETH default
        const maxDeposits = process.env.MAX_NATIVE_DEPOSITS || "100"; // 100 deposits default
        const decimalsHere = process.env.DECIMALS_HERE || "18"; // 18 decimals for ETH
        const decimalsOnN3 = process.env.DECIMALS_ON_N3 || "8"; // 8 decimals on N3 typically

        try {
            console.log(`Setting initial native bridge configuration:`);
            console.log(`- Withdrawal fee: ${ethers.formatEther(withdrawalFee)} ETH`);
            console.log(`- Min withdrawal: ${ethers.formatEther(minWithdrawalAmount)} ETH`);
            console.log(`- Max withdrawal: ${ethers.formatEther(maxWithdrawalAmount)} ETH`);
            console.log(`- Max deposits: ${maxDeposits}`);
            console.log(`- Decimals here: ${decimalsHere}`);
            console.log(`- Decimals on N3: ${decimalsOnN3}`);

            const setupTx = await bridge.connect(governor).setNativeBridge(
                withdrawalFee,
                minWithdrawalAmount,
                maxWithdrawalAmount,
                maxDeposits,
                decimalsHere,
                decimalsOnN3
            );
            await setupTx.wait();
            console.log(`Native bridge configured successfully. TX: ${setupTx.hash}`);

        } catch (error) {
            console.error("Error setting up native bridge:", error);
            throw error;
        }
    }

    console.log("\nNative bridge configuration completed successfully!");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

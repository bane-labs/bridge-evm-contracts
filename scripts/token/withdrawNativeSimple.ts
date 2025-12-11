import { ethers } from 'hardhat';
import { getPersonalWallet } from '../utils/wallet';

async function main() {
    const signer = getPersonalWallet(ethers.provider);
    const bridgeAddress = process.env.BRIDGE_ADDRESS!;
    const recipient = process.env.RECIPIENT!;
    const amount = process.env.AMOUNT!;

    if (!bridgeAddress || !recipient || !amount) {
        throw new Error('BRIDGE_ADDRESS, RECIPIENT, and AMOUNT env vars required');
    }

    const bridge = await ethers.getContractAt('TestBridge', bridgeAddress, signer);

    // Get the fee from the blockchain configuration
    const nativeBridge = await bridge.nativeBridge();
    const feeAmount = nativeBridge.config.fee;

    console.log(`Using fee from blockchain: ${ethers.formatEther(feeAmount)} ETH`);

    // Check sender balance
    const senderAddress = await signer.getAddress();
    const balance = await ethers.provider.getBalance(senderAddress);
    console.log(`Sender address: ${senderAddress}`);
    console.log(`Sender balance: ${ethers.formatEther(balance)} ETH`);

    const withdrawalAmount = ethers.parseEther(amount);
    const decimalScalingFactor = nativeBridge.config.decimalScalingFactor;
    const scalingDivisor = 10n ** BigInt(decimalScalingFactor);
    if (withdrawalAmount % scalingDivisor !== 0n) {
        throw new Error(`Withdrawal amount must be divisible by 10^${decimalScalingFactor} (${scalingDivisor}). Provided: ${withdrawalAmount}`);
    }
    const totalValue = withdrawalAmount + feeAmount;

    console.log(`Withdrawal amount: ${ethers.formatEther(withdrawalAmount)} ETH`);
    console.log(`Fee: ${ethers.formatEther(feeAmount)} ETH`);
    console.log(`Total value needed: ${ethers.formatEther(totalValue)} ETH`);

    if (balance < totalValue) {
        throw new Error(`Insufficient funds! Need ${ethers.formatEther(totalValue)} ETH but have ${ethers.formatEther(balance)} ETH`);
    }

    console.log('Attempting withdrawal...');
    const tx = await bridge.withdrawNative(recipient, feeAmount, { value: totalValue });
    const receipt = await tx.wait();
    if (!receipt) {
        throw new Error('Transaction failed or receipt is null');
    }
    console.log('WithdrawNative tx:', receipt.hash);
}

main().catch((e) => { console.error(e); process.exit(1); });

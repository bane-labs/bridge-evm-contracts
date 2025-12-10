import { ethers } from 'hardhat';
import { getPersonalWallet } from '../utils/wallet';

async function main() {
    const signer = getPersonalWallet(ethers.provider);
    const bridgeAddress = process.env.BRIDGE_ADDRESS!;
    const recipient = process.env.RECIPIENT!;
    const amount = process.env.AMOUNT || '0.1';

    if (!bridgeAddress || !recipient) {
        throw new Error('BRIDGE_ADDRESS and RECIPIENT env vars required');
    }

    const bridge = await ethers.getContractAt('TestBridge', bridgeAddress, signer);

    console.log('=== Native Bridge State BEFORE Withdrawal ===');

    // Read the native bridge state
    const nativeBridgeBefore = await bridge.nativeBridge();
    console.log('Native Bridge Config:');
    let maxFee = nativeBridgeBefore.config.fee;
    console.log(`  Fee: ${ethers.formatEther(maxFee)} ETH`);
    console.log(`  Min Amount: ${ethers.formatEther(nativeBridgeBefore.config.minAmount)} ETH`);
    console.log(`  Max Amount: ${ethers.formatEther(nativeBridgeBefore.config.maxAmount)} ETH`);
    console.log(`  Max Deposits: ${nativeBridgeBefore.config.maxDeposits}`);
    console.log(`  Decimal Scaling Factor: ${nativeBridgeBefore.config.decimalScalingFactor}`);
    console.log('');

    console.log('Native Bridge State:');
    console.log(`  Paused: ${nativeBridgeBefore.paused}`);
    console.log('');

    console.log('Deposit State:');
    console.log(`  Nonce: ${nativeBridgeBefore.depositState.nonce}`);
    console.log(`  Root: ${nativeBridgeBefore.depositState.root}`);
    console.log('');

    console.log('Withdrawal State:');
    console.log(`  Nonce: ${nativeBridgeBefore.withdrawalState.nonce}`);
    console.log(`  Root: ${nativeBridgeBefore.withdrawalState.root}`);
    console.log('');

    // Check sender balance
    const senderAddress = await signer.getAddress();
    const balance = await ethers.provider.getBalance(senderAddress);
    console.log(`Sender: ${senderAddress}`);
    console.log(`Sender Balance: ${ethers.formatEther(balance)} ETH`);
    console.log('');

    // Calculate amounts
    const withdrawalAmount = ethers.parseEther(amount);
    const feeAmount = nativeBridgeBefore.config.fee; // Use fee from blockchain config
    const totalValue = withdrawalAmount + feeAmount;

    console.log('Withdrawal Parameters:');
    console.log(`  Recipient: ${recipient}`);
    console.log(`  Withdrawal Amount: ${ethers.formatEther(withdrawalAmount)} ETH`);
    console.log(`  Fee (from blockchain): ${ethers.formatEther(feeAmount)} ETH`);
    console.log(`  Total Value: ${ethers.formatEther(totalValue)} ETH`);
    console.log('');

    if (balance < totalValue) {
        throw new Error(`Insufficient funds! Need ${ethers.formatEther(totalValue)} ETH but have ${ethers.formatEther(balance)} ETH`);
    }

    console.log('=== Performing Withdrawal ===');
    const tx = await bridge.withdrawNative(recipient, feeAmount, { value: totalValue });
    console.log(`Transaction submitted: ${tx.hash}`);

    const receipt = await tx.wait();
    if (!receipt || receipt.status !== 1) {
        throw new Error(`Transaction failed: ${tx.hash}`);
    }
    console.log(`Transaction confirmed in block: ${receipt.blockNumber}`);
    console.log(`Gas used: ${receipt.gasUsed}`);
    console.log('');

    // Parse events from the transaction
    console.log('=== Transaction Events ===');
    for (const log of receipt.logs) {
        try {
            const parsed = bridge.interface.parseLog(log);
            if (parsed) {
                console.log(`Event: ${parsed.name}`);
                console.log(`  Args:`, parsed.args);
                console.log('');
            }
        } catch (e) {
            // Skip unparseable logs
        }
    }

    console.log('=== Native Bridge State AFTER Withdrawal ===');

    // Read the native bridge state again
    const nativeBridgeAfter = await bridge.nativeBridge();

    console.log('Deposit State:');
    console.log(`  Nonce: ${nativeBridgeAfter.depositState.nonce} (was: ${nativeBridgeBefore.depositState.nonce})`);
    console.log(`  Root: ${nativeBridgeAfter.depositState.root} (was: ${nativeBridgeBefore.depositState.root})`);
    console.log('');

    console.log('Withdrawal State:');
    console.log(`  Nonce: ${nativeBridgeAfter.withdrawalState.nonce} (was: ${nativeBridgeBefore.withdrawalState.nonce})`);
    console.log(`  Root: ${nativeBridgeAfter.withdrawalState.root} (was: ${nativeBridgeBefore.withdrawalState.root})`);
    console.log('');

    // Show changes
    console.log('=== State Changes ===');
    const nonceChange = nativeBridgeAfter.withdrawalState.nonce - nativeBridgeBefore.withdrawalState.nonce;
    const rootChanged = nativeBridgeAfter.withdrawalState.root !== nativeBridgeBefore.withdrawalState.root;

    console.log(`Withdrawal nonce increased by: ${nonceChange}`);
    console.log(`Withdrawal root changed: ${rootChanged}`);

    if (rootChanged) {
        console.log(`  Old root: ${nativeBridgeBefore.withdrawalState.root}`);
        console.log(`  New root: ${nativeBridgeAfter.withdrawalState.root}`);
    }

    // Check final balance
    const finalBalance = await ethers.provider.getBalance(senderAddress);
    const balanceChange = balance - finalBalance;
    console.log(`Sender balance change: -${ethers.formatEther(balanceChange)} ETH`);
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});

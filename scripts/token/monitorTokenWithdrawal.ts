import { ethers } from 'hardhat';
import { getPersonalWallet } from '../utils/wallet';

async function main() {
    const signer = getPersonalWallet(ethers.provider);
    const bridgeAddress = process.env.BRIDGE_ADDRESS!;
    const tokenAddress = process.env.TOKEN_ADDRESS!;
    const recipient = process.env.RECIPIENT!;
    const amount = process.env.AMOUNT || '1';

    if (!bridgeAddress || !tokenAddress || !recipient) {
        throw new Error('BRIDGE_ADDRESS, TOKEN_ADDRESS and RECIPIENT env vars required');
    }

    const bridge = await ethers.getContractAt('TestBridge', bridgeAddress, signer);
    const token = await ethers.getContractAt('IERC20', tokenAddress, signer);

    console.log('=== Token Bridge State BEFORE Withdrawal ===');

    // Read the token bridge state
    const tokenBridgeBefore = await bridge.tokenBridges(tokenAddress);
    console.log(`Token: ${tokenAddress}`);
    console.log('Token Bridge Config:');
    console.log(`  Fee: ${ethers.formatEther(tokenBridgeBefore.config.fee)} ETH`);
    console.log(`  Min Amount: ${ethers.formatUnits(tokenBridgeBefore.config.minAmount, 18)} tokens`);
    console.log(`  Max Amount: ${ethers.formatUnits(tokenBridgeBefore.config.maxAmount, 18)} tokens`);
    console.log(`  Max Deposits: ${tokenBridgeBefore.config.maxDeposits}`);
    console.log(`  Decimal Scaling Factor: ${tokenBridgeBefore.config.decimalScalingFactor}`);
    console.log('');

    console.log('Token Bridge State:');
    console.log(`  Paused: ${tokenBridgeBefore.paused}`);
    console.log('');

    console.log('Deposit State:');
    console.log(`  Nonce: ${tokenBridgeBefore.depositState.nonce}`);
    console.log(`  Root: ${tokenBridgeBefore.depositState.root}`);
    console.log('');

    console.log('Withdrawal State:');
    console.log(`  Nonce: ${tokenBridgeBefore.withdrawalState.nonce}`);
    console.log(`  Root: ${tokenBridgeBefore.withdrawalState.root}`);
    console.log('');

    // Check sender balances
    const senderAddress = await signer.getAddress();
    const ethBalance = await ethers.provider.getBalance(senderAddress);
    const tokenBalance = await token.balanceOf(senderAddress);
    console.log(`Sender: ${senderAddress}`);
    console.log(`ETH Balance: ${ethers.formatEther(ethBalance)} ETH`);
    console.log(`Token Balance: ${ethers.formatUnits(tokenBalance, 18)} tokens`);
    console.log('');

    // Get token info
    let tokenSymbol = "UNKNOWN";
    let tokenDecimals: any = 18;
    try {
        const erc20Detailed = await ethers.getContractAt("TestToken", tokenAddress);
        tokenSymbol = await erc20Detailed.symbol();
        tokenDecimals = await erc20Detailed.decimals();
        console.log(`Token Symbol: ${tokenSymbol}`);
        console.log(`Token Decimals: ${tokenDecimals}`);
    } catch {
        console.log('Could not get token symbol/decimals, using defaults');
    }
    console.log('');

    // Calculate amounts
    const withdrawalAmount = ethers.parseUnits(amount, tokenDecimals);
    const feeAmount = tokenBridgeBefore.config.fee; // Always use the fee from blockchain config

    console.log('Withdrawal Parameters:');
    console.log(`  Recipient: ${recipient}`);
    console.log(`  Withdrawal Amount: ${ethers.formatUnits(withdrawalAmount, tokenDecimals)} ${tokenSymbol}`);
    console.log(`  Fee (from blockchain): ${ethers.formatEther(feeAmount)} ETH`);
    console.log('');

    // Check sufficient balances
    if (ethBalance < feeAmount) {
        throw new Error(`Insufficient ETH for fee! Need ${ethers.formatEther(feeAmount)} ETH but have ${ethers.formatEther(ethBalance)} ETH`);
    }

    if (tokenBalance < withdrawalAmount) {
        throw new Error(`Insufficient tokens! Need ${ethers.formatUnits(withdrawalAmount, tokenDecimals)} ${tokenSymbol} but have ${ethers.formatUnits(tokenBalance, tokenDecimals)} ${tokenSymbol}`);
    }

    // Check token allowance
    const allowance = await token.allowance(senderAddress, bridgeAddress);
    console.log(`Current allowance: ${ethers.formatUnits(allowance, tokenDecimals)} ${tokenSymbol}`);

    if (allowance < withdrawalAmount) {
        console.log('=== Approving Token Spending ===');
        const approveTx = await token.approve(bridgeAddress, withdrawalAmount);
        console.log(`Approve transaction submitted: ${approveTx.hash}`);
        await approveTx.wait();
        console.log('Token approval confirmed');
        console.log('');
    }

    console.log('=== Performing Token Withdrawal ===');
    const tx = await bridge.withdrawToken(tokenAddress, recipient, withdrawalAmount, { value: feeAmount });
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
            // Try parsing as token events
            try {
                const tokenParsed = token.interface.parseLog(log);
                if (tokenParsed) {
                    console.log(`Token Event: ${tokenParsed.name}`);
                    console.log(`  Args:`, tokenParsed.args);
                    console.log('');
                }
            } catch (e2) {
                // Skip unparseable logs
            }
        }
    }

    console.log('=== Token Bridge State AFTER Withdrawal ===');

    // Read the token bridge state again
    const tokenBridgeAfter = await bridge.tokenBridges(tokenAddress);

    console.log('Deposit State:');
    console.log(`  Nonce: ${tokenBridgeAfter.depositState.nonce} (was: ${tokenBridgeBefore.depositState.nonce})`);
    console.log(`  Root: ${tokenBridgeAfter.depositState.root} (was: ${tokenBridgeBefore.depositState.root})`);
    console.log('');

    console.log('Withdrawal State:');
    console.log(`  Nonce: ${tokenBridgeAfter.withdrawalState.nonce} (was: ${tokenBridgeBefore.withdrawalState.nonce})`);
    console.log(`  Root: ${tokenBridgeAfter.withdrawalState.root} (was: ${tokenBridgeBefore.withdrawalState.root})`);
    console.log('');

    // Show changes
    console.log('=== State Changes ===');
    const nonceChange = tokenBridgeAfter.withdrawalState.nonce - tokenBridgeBefore.withdrawalState.nonce;
    const rootChanged = tokenBridgeAfter.withdrawalState.root !== tokenBridgeBefore.withdrawalState.root;

    console.log(`Withdrawal nonce increased by: ${nonceChange}`);
    console.log(`Withdrawal root changed: ${rootChanged}`);

    if (rootChanged) {
        console.log(`  Old root: ${tokenBridgeBefore.withdrawalState.root}`);
        console.log(`  New root: ${tokenBridgeAfter.withdrawalState.root}`);
    }

    // Check final balances
    const finalEthBalance = await ethers.provider.getBalance(senderAddress);
    const finalTokenBalance = await token.balanceOf(senderAddress);
    const ethChange = ethBalance - finalEthBalance;
    const tokenChange = tokenBalance - finalTokenBalance;

    console.log(`ETH balance change: -${ethers.formatEther(ethChange)} ETH`);
    console.log(`Token balance change: -${ethers.formatUnits(tokenChange, tokenDecimals)} ${tokenSymbol}`);
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});

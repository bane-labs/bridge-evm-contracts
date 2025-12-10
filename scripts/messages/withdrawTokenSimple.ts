import { ethers } from 'hardhat';
import { getPersonalWallet } from '../utils/wallet';

async function main() {
    const signer = getPersonalWallet(ethers.provider);
    const bridgeAddress = process.env.BRIDGE_ADDRESS!;
    const tokenAddress = process.env.TOKEN_ADDRESS!;
    const recipient = process.env.RECIPIENT!;
    const amount = process.env.AMOUNT!;

    if (!bridgeAddress || !tokenAddress || !recipient || !amount) {
        throw new Error('BRIDGE_ADDRESS, TOKEN_ADDRESS, RECIPIENT, and AMOUNT env vars required');
    }

    const bridge = await ethers.getContractAt('TestBridge', bridgeAddress, signer);
    const token = await ethers.getContractAt('IERC20', tokenAddress, signer);

    // Get token info
    let tokenDecimals = 18;
    try {
        const erc20Detailed = await ethers.getContractAt("TestToken", tokenAddress);
        tokenDecimals = await erc20Detailed.decimals();
    } catch {
        console.log('Could not get token decimals, using 18');
    }

    // Get the fee from the blockchain configuration
    const tokenBridge = await bridge.tokenBridges(tokenAddress);
    const feeAmount = tokenBridge.config.fee;

    console.log(`Using fee from blockchain: ${ethers.formatEther(feeAmount)} ETH`);

    const withdrawalAmount = ethers.parseUnits(amount, tokenDecimals);

    // Check current allowance
    const senderAddress = await signer.getAddress();
    const currentAllowance = await token.allowance(senderAddress, bridgeAddress);

    if (currentAllowance < withdrawalAmount) {
        console.log('Approving token spending...');
        const approveTx = await token.approve(bridgeAddress, withdrawalAmount);
        await approveTx.wait(); // Wait for approval confirmation
        console.log('Token approval confirmed');
    } else {
        console.log('Sufficient allowance already exists');
    }

    // Then call withdrawToken with fee as msg.value
    const tx = await bridge.withdrawToken(tokenAddress, recipient, withdrawalAmount, { value: feeAmount });
    const receipt = await tx.wait();
    console.log('WithdrawToken tx:', receipt.hash);
}

main().catch((e) => { console.error(e); process.exit(1); });


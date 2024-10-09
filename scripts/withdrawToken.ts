import { ethers } from "hardhat";
import { deployBridgeContracts } from "./deploy/bridge";
import { defaultN3TokenAddress, getBridgeFromEnv, getN3DefaultRecipientFromEnv, getNeoXTokenFromEnv } from "./utils/addresses";
import { MAX_FEE_PER_GAS, TokenExecutionType } from "./utils/constants";
import { fundIfLocalNetwork, isLocalNetwork } from "./utils/network";
import { getDeployer, getOwner } from "./utils/wallet";
import { deployTokenContract } from "./deploy/token";
import { registerToken } from "./utils/registration";

async function main() {
    // Using the deployer account since it'll have some gas balance that can be used to withdraw
    const sender = getDeployer(ethers.provider);
    const governor = getOwner(ethers.provider);
    await fundIfLocalNetwork([sender.address]);

    var bridge;
    var token;
    if (isLocalNetwork(await ethers.provider.getNetwork())) {
        bridge = await deployBridgeContracts();
        token = await deployTokenContract(sender);
        await registerToken(bridge, governor, token, TokenExecutionType.ERC20, defaultN3TokenAddress());
    } else {
        bridge = await getBridgeFromEnv(ethers.provider);
        token = await getNeoXTokenFromEnv();
    }
    const tokenAddress = await token.getAddress();
    const amount = ethers.parseEther("10");
    const n3Recipient = getN3DefaultRecipientFromEnv();
    const bridgeAddress = await bridge.getAddress();

    await token.connect(sender).approve(bridgeAddress, amount, { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_FEE_PER_GAS });

    const tokenConfig = await bridge.getTokenConfig(tokenAddress);
    const withdrawTx = await bridge.connect(sender).withdrawToken(tokenAddress, n3Recipient, amount, { value: tokenConfig.fee, maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_FEE_PER_GAS });

    const receipt = await withdrawTx.wait();
    console.log("Withdraw Gas Transaction: ", receipt?.hash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

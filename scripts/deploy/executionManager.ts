import { ethers } from "hardhat";
import { Wallet } from "ethers";
import { MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "../utils/constants";
import { fundIfLocalNetwork } from "../utils/network";
import { ExecutionManager } from "../../typechain-types";

// IMPORTANT: This script deploys the ExecutionManager contract.
export async function deployExecutionManager(deployer: Wallet, bridgeAddress: any): Promise<ExecutionManager> {
    await fundIfLocalNetwork([deployer.address]);

    // Deploy the execution manager contract
    const executionManager = await (await ethers.getContractFactory("ExecutionManager"))
        .connect(deployer)
        .deploy(bridgeAddress, {
            maxFeePerGas: MAX_FEE_PER_GAS,
            maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS
        });

    // Wait for deployment confirmation
    await executionManager.waitForDeployment();

    const contractAddress = await executionManager.getAddress();
    console.log("Execution Manager deployed at:            ", contractAddress);
    console.log("Message Bridge Contract address used:     ", bridgeAddress);

    // Verify the contract has code deployed
    // Added this b/c in the devnet the BRIDGE_ROLE check was giving `0x` and causing an error in deployments
    const provider = deployer.provider;
    let code: string;
    if (provider) {
        code = await provider.getCode(contractAddress);
    } else {
        throw new Error('Deployer has no provider');
    }
    if (code === '0x') {
        throw new Error('Contract deployment failed - no code at address');
    }

    try {
        const bridgeRole = await executionManager.BRIDGE_ROLE();
        console.log("Verification of Bridge Role:              ", await executionManager.hasRole(bridgeRole, bridgeAddress));
    } catch (error) {
        console.error("Error calling BRIDGE_ROLE - check if function exists in contract");
        throw error;
    }

    return executionManager;
}

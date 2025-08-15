import { ethers } from "hardhat";
import { Wallet } from "ethers";
import { MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "../utils/constants";
import { fundIfLocalNetwork } from "../utils/network";
import { ExecutionManager } from "../../typechain-types";

// IMPORTANT: This script deploys the ExecutionManager contract.
export async function deployExecutionManager(deployer: Wallet, bridgeAddress: any): Promise<ExecutionManager> {
    await fundIfLocalNetwork([deployer.address]);
    // Deploy the execution manager contract
    const executionManager = await (await ethers.getContractFactory("ExecutionManager")).connect(deployer).deploy(bridgeAddress, { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS });

    console.log("Execution Manager deployed at:            ", await executionManager.getAddress());
    console.log("Message Bridge Contract address used:     ", bridgeAddress);
    console.log("Verification of Bridge Role:              ", await executionManager.hasRole(await executionManager.BRIDGE_ROLE(), bridgeAddress));
    return executionManager;
}

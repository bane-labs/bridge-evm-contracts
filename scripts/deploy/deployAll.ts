import { ethers } from "hardhat";
import { printFeeConfiguration, MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "../utils/constants";
import { fundIfLocalNetwork, printNetworkConfiguration } from "../utils/network";
import { getDeployer, getGovernor, getOwner } from "../utils/wallet";
import { deployBridgeManagement } from "./management";
import { deployBridge } from "./bridge";
import { deployMessageBridge } from "./messageBridge";
import { deployExecutionManager } from "./executionManager";
import { TestBridgeManagement, TestBridge, TestMessageBridge, ExecutionManager } from "../../typechain-types";

export async function deployAll(): Promise<void> {
    console.log("\n#####################################################################");
    console.log("#################### Deployment of All Contracts ####################");
    console.log("#####################################################################");
    await printNetworkConfiguration();
    printFeeConfiguration();
    console.log("Max Priority Fee Per Gas (gasFeeCap):", ethers.formatUnits(MAX_PRIORITY_FEE_PER_GAS, "gwei"), "gwei");
    console.log("Max Fee Per Gas (gasTipCap):         ", ethers.formatUnits(MAX_FEE_PER_GAS, "gwei"), "gwei");

    const deployer = getDeployer(ethers.provider);
    const owner = getOwner(ethers.provider);
    
    const management = await deployBridgeManagement(deployer);
    const managementAddress = await management.getAddress();
    
    const bridge = await deployBridge(managementAddress, deployer, owner);
    const bridgeAddress = await bridge.getAddress();

    const messageBridge = await deployMessageBridge(managementAddress, deployer);
    const messageBridgeAddress = await messageBridge.getAddress();
    
    const executionManager = await deployExecutionManager(deployer, messageBridgeAddress, false);
    const executionManagerAddress = await executionManager.getAddress();
    
    const governor = getGovernor(ethers.provider);
    
    await fundIfLocalNetwork([governor.address], false);
    await messageBridge.connect(governor).setExecutionManager(executionManagerAddress);

    await ensureConsistentState(management, bridge, messageBridge, executionManager);

    console.log("\n🏁 Summary of Deployed Contracts (without logic addresses)");
    console.log("BridgeManagement: ", managementAddress);
    console.log("Bridge:           ", bridgeAddress);
    console.log("MessageBridge:    ", messageBridgeAddress);
    console.log("ExecutionManager: ", executionManagerAddress);
}

async function ensureConsistentState(management: TestBridgeManagement, bridge: TestBridge, messageBridge: TestMessageBridge, executionManager: ExecutionManager): Promise<void> {
    const managementAddress = await management.getAddress();
    const messageBridgeAddress = await messageBridge.getAddress();
    const executionManagerAddress = await executionManager.getAddress();

    console.log("\n🔍 Ensuring consistent state across deployed contracts...");
    if (matches(await bridge.management(), managementAddress)) {
        console.log("✅ BridgeManagement address correctly set on Bridge contract");
    } else {
        throw new Error("BridgeManagement address on Bridge does not match deployed management contract address");
    }
    if (matches(await messageBridge.management(), managementAddress)) {
        console.log("✅ BridgeManagement address correctly set on MessageBridge contract");
    } else {
        throw new Error("BridgeManagement address on MessageBridge does not match deployed BridgeManagement contract address");
    }
    if (matches(await messageBridge.executionManager(), executionManagerAddress)) {
        console.log("✅ ExecutionManager address correctly set on MessageBridge contract");
    } else {
        throw new Error("ExecutionManager address on MessageBridge does not match deployed ExecutionManager contract address");
    }
    if (await executionManager.hasRole(await executionManager.BRIDGE_ROLE(), messageBridgeAddress)) {
        console.log("✅ MessageBridge has bridge role privileges on ExecutionManager contract");
    } else {
        throw new Error("MessageBridge does not have bridge role privileges on ExecutionManager contract");
    }
}

function matches(actual: string, expected: string): boolean {
    return actual.toLowerCase() === expected.toLowerCase();
}

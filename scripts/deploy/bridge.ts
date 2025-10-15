import { ethers, upgrades } from "hardhat";
import { Wallet } from "ethers";
import { TestBridge } from "../../typechain-types/contracts/tests";
import { printFeeConfiguration, MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "../utils/constants";
import { fundIfLocalNetwork, printNetworkConfiguration } from "../utils/network";
import { getDeployer, getOwner } from "../utils/wallet";
import { deployBridgeManagement } from "./management";

// IMPORTANT: This script deploys the TestBridge contract, which is a test contract that is not meant to be used in production.
export async function deployBridge(managementAddress: string, deployer: Wallet, owner: Wallet): Promise<TestBridge> {
    await fundIfLocalNetwork([deployer.address, owner.address], false);
    // Deploy the bridge contract behind a proxy
    const BridgeFactory = (await ethers.getContractFactory("TestBridge")).connect(deployer);
    const bridgeProxy = await upgrades.deployProxy(BridgeFactory, [managementAddress], { kind: "uups", unsafeAllow: ["constructor"], txOverrides: { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS } });
    await bridgeProxy.waitForDeployment();
    const bridge = await ethers.getContractAt("TestBridge", await bridgeProxy.getAddress());

    console.log("\n📝 Deployment of Bridge");
    console.log("Bridge Proxy: ", await bridge.getAddress());
    console.log("Bridge Logic: ", await upgrades.erc1967.getImplementationAddress(await bridge.getAddress()));

    console.log("\n💾 Bridge Configuration");
    console.log("Linked Management:          ", await bridge.management());
    return bridge;
}

export async function deployBridgeContracts(): Promise<TestBridge> {
    console.log("\n#####################################################################");
    console.log("#################### Bridge Contracts Deployment ####################");
    console.log("#####################################################################");
    await printNetworkConfiguration();
    printFeeConfiguration();
    console.log("Max Priority Fee Per Gas (gasFeeCap):", ethers.formatUnits(MAX_PRIORITY_FEE_PER_GAS, "gwei"), "gwei");
    console.log("Max Fee Per Gas (gasTipCap):         ", ethers.formatUnits(MAX_FEE_PER_GAS, "gwei"), "gwei");

    const deployer = getDeployer(ethers.provider);
    const owner = getOwner(ethers.provider);
    const management = await deployBridgeManagement(deployer);
    const bridge = await deployBridge(await management.getAddress(), deployer, owner);
    return bridge;
}

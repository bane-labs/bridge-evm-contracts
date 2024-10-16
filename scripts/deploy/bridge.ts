import { ethers, upgrades } from "hardhat";
import { Wallet } from "ethers";
import { TestBridge } from "../../typechain-types/contracts/tests";
import { printFeeConfiguration, MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "../utils/constants";
import { fundIfLocalNetwork, printNetworkConfiguration } from "../utils/network";
import { getDeployer } from "../utils/wallet";
import { deployBridgeManagement } from "./management";

// IMPORTANT: This script deploys the TestBridge contract, which is a test contract that is not meant to be used in production.
export async function deployBridge(managementAddress: string, deployer: Wallet): Promise<TestBridge> {
    // Deploy the bridge contract behind a proxy
    const BridgeFactory = (await ethers.getContractFactory("TestBridge")).connect(deployer);
    const fee = ethers.parseEther("0.1");
    const minAmount = ethers.parseEther("1");
    const maxAmount = ethers.parseEther("10000");
    const bridgeProxy = await upgrades.deployProxy(BridgeFactory, [managementAddress, fee, minAmount, maxAmount, 100], { kind: "uups", unsafeAllow: ["constructor"], txOverrides: { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS } });
    await bridgeProxy.waitForDeployment();
    const bridge = await ethers.getContractAt("TestBridge", await bridgeProxy.getAddress());

    console.log("\n# Deployment");
    console.log("Bridge Proxy Address:     ", await bridge.getAddress());
    console.log("Bridge Logic Address:     ", await upgrades.erc1967.getImplementationAddress(await bridge.getAddress()));

    console.log("\n# Bridge Configuration");
    console.log("Linked Management:       ", await bridge.management());
    const gasBridge = await bridge.gasBridge();
    console.log("Gas Bridge Fee:          ", ethers.formatEther(gasBridge.config.fee));
    console.log("Gas Bridge Min Amount:   ", ethers.formatEther(gasBridge.config.minAmount));
    console.log("Gas Bridge Max Amount:   ", ethers.formatEther(gasBridge.config.maxAmount));
    console.log("Gas Bridge Max Deposits: ", gasBridge.config.maxDeposits.toString());
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
    await fundIfLocalNetwork([deployer.address]);
    const management = await deployBridgeManagement(deployer);
    const bridge = await deployBridge(await management.getAddress(), deployer);
    return bridge;
}

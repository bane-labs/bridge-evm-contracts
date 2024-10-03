import { ethers, upgrades } from "hardhat";
import { Wallet } from "ethers";
import { TestBridgeManagement, TestBridge } from "../typechain-types/contracts/tests/";
import { printFeeConfiguration, MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "./utils/constants";
import { getDeployer, getOwner, getRelayer, getValidator01, getValdiator02 } from "./utils/wallet";
import { fundIfLocalNetwork, printNetworkConfiguration } from "./utils/network";

export async function deployBridgeManagement(deployer: Wallet): Promise<TestBridgeManagement> {
    console.log("\n#################### Bridge Management Deployment ###################");
    const owner = getOwner(ethers.provider);
    const relayer = getRelayer();
    const validator01 = getValidator01();
    const validator02 = getValdiator02();
    const governor = owner;
    const securityGuard = owner;
    const funder = owner;
    // Deploy the management contract behind a proxy
    const ManagementFactory = (await ethers.getContractFactory("TestBridgeManagement")).connect(deployer);
    const managementProxy = await upgrades.deployProxy(ManagementFactory, [owner.address, relayer.address, 2, [validator01.address, validator02.address], governor.address, securityGuard.address, funder.address], { kind: "uups", unsafeAllow: ["constructor"], txOverrides: { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS } });
    await managementProxy.waitForDeployment();
    const management = managementProxy as TestBridgeManagement;
    console.log("\n# Deployment");
    console.log("Management Proxy Address: ", await management.getAddress());
    console.log("Management Logic Address: ", await upgrades.erc1967.getImplementationAddress(await management.getAddress()));

    console.log("\n# Roles");
    console.log("Owner:               ", await management.owner());
    console.log("Relayer:             ", await management.getRelayer());
    console.log("Validator Threshold: ", (await management.getValidatorThreshold()).toString());
    console.log("Validator 1:         ", await management.getValidator(0));
    console.log("Validator 2:         ", await management.getValidator(1));
    console.log("Governor:            ", await management.getGovernor());
    console.log("Security Guard:      ", await management.getSecurityGuard());
    console.log("Funder:              ", await management.getFunder());
    return management;
}

export async function deployBridge(managementAddress: string, deployer: Wallet): Promise<TestBridge> {
    console.log("\n########################## Bridge Deployment ########################");
    // Deploy the bridge contract behind a proxy
    const BridgeFactory = (await ethers.getContractFactory("TestBridge")).connect(deployer);
    const fee = ethers.parseEther("0.1");
    const minAmount = ethers.parseEther("1");
    const maxAmount = ethers.parseEther("10000");
    const bridgeProxy = await upgrades.deployProxy(BridgeFactory, [managementAddress, fee, minAmount, maxAmount, 100], { kind: "uups", unsafeAllow: ["constructor"], txOverrides: { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS } });
    await bridgeProxy.waitForDeployment();
    const bridge = bridgeProxy as TestBridge;

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
    console.log("\n######################### End of Deployment #########################");
    return bridge;
}

export async function deployBridgeContracts() {
    console.log("\n#################### Bridge Contracts Deployment ####################");
    const network = await ethers.provider.getNetwork();
    printNetworkConfiguration(network);
    printFeeConfiguration();
    console.log("Max Priority Fee Per Gas (gasFeeCap):", ethers.formatUnits(MAX_PRIORITY_FEE_PER_GAS, "gwei"), "gwei");
    console.log("Max Fee Per Gas (gasTipCap):         ", ethers.formatUnits(MAX_FEE_PER_GAS, "gwei"), "gwei");

    const deployer = getDeployer(ethers.provider);
    await fundIfLocalNetwork(network, deployer.address);
    const management = await deployBridgeManagement(deployer);
    await deployBridge(await management.getAddress(), deployer);
    console.log("\n################# End of Bridge Contracts Deployment ################");
}

deployBridgeContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

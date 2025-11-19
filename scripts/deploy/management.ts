import { ethers, upgrades } from "hardhat";
import { Wallet } from "ethers";
import { TestBridgeManagement } from "../../typechain-types/contracts/tests";
import { MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "../utils/constants";
import { fundIfLocalNetwork } from "../utils/network";
import { getOwner, getRelayer, getValidator01, getValidator02, getGovernor } from "../utils/wallet";

// IMPORTANT: This script deploys the TestBridgeManagement contract, which is a test contract that is not meant to be used in production.
export async function deployBridgeManagement(deployer: Wallet): Promise<TestBridgeManagement> {
    const owner = getOwner(ethers.provider);
    const relayer = getRelayer();
    const validator01 = getValidator01();
    const validator02 = getValidator02();
    const governor = getGovernor(ethers.provider);
    const securityGuard = owner;
    const funder = owner;
    await fundIfLocalNetwork([deployer.address, owner.address], false);
    // Deploy the management contract behind a proxy
    const ManagementFactory = (await ethers.getContractFactory("TestBridgeManagement")).connect(deployer);
    const managementProxy = await upgrades.deployProxy(ManagementFactory, [owner.address, relayer.address, 2, [validator01.address, validator02.address], governor.address, securityGuard.address, funder.address], { kind: "uups", unsafeAllow: ["constructor", "missing-initializer"], txOverrides: { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS } });
    await managementProxy.waitForDeployment();
    const management = await ethers.getContractAt("TestBridgeManagement", await managementProxy.getAddress());

    console.log("\nDeployment of BridgeManagement");
    console.log("BridgeManagement Proxy: ", await management.getAddress());
    console.log("BridgeManagement Logic: ", await upgrades.erc1967.getImplementationAddress(await management.getAddress()));

    console.log("\nRoles");
    console.log("Owner:               ", await management.owner());
    console.log("Relayer:             ", await management.getRelayer());
    console.log("Validator Threshold: ", (await management.getValidatorThreshold()).toString());
    console.log("Validator 1:         ", (await management.getValidators())[0]);
    console.log("Validator 2:         ", (await management.getValidators())[1]);
    console.log("Governor:            ", await management.getGovernor());
    console.log("Security Guard:      ", await management.getSecurityGuard());
    console.log("Funder:              ", await management.getFunder());
    return management;
}

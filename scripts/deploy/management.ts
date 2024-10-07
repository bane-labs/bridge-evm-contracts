import { ethers, upgrades } from "hardhat";
import { Wallet } from "ethers";
import { TestBridgeManagement } from "../../typechain-types/contracts/tests";
import { MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "../utils/constants";
import { getOwner, getRelayer, getValidator01, getValdiator02 } from "../utils/wallet";

export async function deployBridgeManagement(deployer: Wallet): Promise<TestBridgeManagement> {
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

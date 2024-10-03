import { ethers, upgrades } from "hardhat";
import { TestBridgeManagement, TestBridge } from "../typechain-types/contracts/tests/";
import { HARDHAT_LOCAL_NETWORK_CHAIN_ID, HARDHAT_DEFAULT_PROVIDER_NETWORK_CHAIN_ID, NEOX_TESTNET_CHAIN_ID, MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "./utils/constants";
import { fundAddress } from "./utils/funding";
import { getDeployer, getOwner, getRelayer, getValidator01, getValdiator02 } from "./utils/wallet";

async function deployBridgeContracts() {
    console.log("\n#################### Bridge Contracts Deployment ####################");
    const network = await ethers.provider.getNetwork();

    const deployer = getDeployer(ethers.provider);
    const owner = getOwner(ethers.provider);
    const relayer = getRelayer();
    const validator01 = getValidator01();
    const validator02 = getValdiator02();
    const governor = owner;
    const securityGuard = owner;
    const funder = owner;

    const chainId = network.chainId;
    const localNetwork = chainId === HARDHAT_LOCAL_NETWORK_CHAIN_ID || chainId === HARDHAT_DEFAULT_PROVIDER_NETWORK_CHAIN_ID;
    console.log("\n# Network Configuration");
    if (localNetwork) {
        console.log("Network:                              Local Hardhat Network");
        console.log("Chain Id:                            ", chainId.toString());
    } else if (chainId === NEOX_TESTNET_CHAIN_ID) {
        console.log("Network:                              Neo X Testnet");
        console.log("Chain Id:                            ", chainId.toString());
    } else {
        throw new Error("Unknown Network");
    }

    console.log("Max Priority Fee Per Gas (gasFeeCap):", ethers.formatUnits(MAX_PRIORITY_FEE_PER_GAS, "gwei"), "gwei");
    console.log("Max Fee Per Gas (gasTipCap):         ", ethers.formatUnits(MAX_FEE_PER_GAS, "gwei"), "gwei");

    if (localNetwork) {
        console.log("\n# Funding");
        const [signer01] = await ethers.getSigners();
        fundAddress(signer01, deployer.address, ethers.parseEther("10"));
        fundAddress(signer01, owner.address, ethers.parseEther("10"));
        fundAddress(signer01, relayer.address, ethers.parseEther("10"));
    }

    // Deploy the management contract behind a proxy
    const ManagementFactory = (await ethers.getContractFactory("TestBridgeManagement")).connect(deployer);
    const managementProxy = await upgrades.deployProxy(ManagementFactory, [owner.address, relayer.address, 2, [validator01.address, validator02.address], governor.address, securityGuard.address, funder.address], { kind: "uups", unsafeAllow: ["constructor"], txOverrides: { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS } });
    await managementProxy.waitForDeployment();
    const management = managementProxy as TestBridgeManagement;

    // Deploy the bridge contract behind a proxy
    const BridgeFactory = (await ethers.getContractFactory("TestBridge")).connect(deployer);
    const managementAddress = await management.getAddress();
    const fee = ethers.parseEther("0.1");
    const minAmount = ethers.parseEther("1");
    const maxAmount = ethers.parseEther("10000");
    const bridgeProxy = await upgrades.deployProxy(BridgeFactory, [managementAddress, fee, minAmount, maxAmount, 100], { kind: "uups", unsafeAllow: ["constructor"], txOverrides: { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS } });
    await bridgeProxy.waitForDeployment();
    const bridge = bridgeProxy as TestBridge;

    console.log("\n# Deployment");
    console.log("Management Logic Address: ", await upgrades.erc1967.getImplementationAddress(await management.getAddress()));
    console.log("Management Proxy Address: ", await management.getAddress());
    console.log("Bridge Logic Address:     ", await upgrades.erc1967.getImplementationAddress(await bridge.getAddress()));
    console.log("Bridge Proxy Address:     ", await bridge.getAddress());

    console.log("\n# Roles");
    console.log("Owner:               ", await management.owner());
    console.log("Relayer:             ", await management.getRelayer());
    console.log("Validator Threshold: ", (await management.getValidatorThreshold()).toString());
    console.log("Validator 1:         ", await management.getValidator(0));
    console.log("Validator 2:         ", await management.getValidator(1));
    console.log("Governor:            ", await management.getGovernor());
    console.log("Security Guard:      ", await management.getSecurityGuard());
    console.log("Funder:              ", await management.getFunder());

    console.log("\n# Bridge Configuration");
    console.log("Linked Management:       ", await bridge.management());
    const gasBridge = await bridge.gasBridge();
    console.log("Gas Bridge Fee:          ", ethers.formatEther(gasBridge.config.fee));
    console.log("Gas Bridge Min Amount:   ", ethers.formatEther(gasBridge.config.minAmount));
    console.log("Gas Bridge Max Amount:   ", ethers.formatEther(gasBridge.config.maxAmount));
    console.log("Gas Bridge Max Deposits: ", gasBridge.config.maxDeposits.toString());

    console.log("\n######################### End of Deployment #########################");
}

deployBridgeContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

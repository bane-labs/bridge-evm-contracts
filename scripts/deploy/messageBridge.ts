import {ethers, upgrades} from 'hardhat';
import {Wallet} from 'ethers';
import {MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS, printFeeConfiguration} from '../utils/constants';
import {fundIfLocalNetwork, printNetworkConfiguration} from '../utils/network';
import {getDeployer, getGovernor} from '../utils/wallet';
import {deployBridgeManagement} from './management';
import {deployExecutionManager} from './executionManager';
import {TestMessageBridge} from '../../typechain-types';

// IMPORTANT: This script deploys the TestMessageBridge contract, which is a test contract that is not meant to be used in production.
export async function deployMessageBridge(managementAddress: string, deployer: Wallet): Promise<TestMessageBridge> {
    const SENDING_FEE = ethers.parseEther("0.1");
    const MAX_MESSAGE_SIZE = 10240; // 10 kb
    const MAX_NR_MESSAGES = 100;
    const EXECUTION_WINDOW_SECONDS = 3600 * 24; // 1 day
    await fundIfLocalNetwork([deployer.address], false);
    // Deploy the bridge contract behind a proxy
    const MessageBridgeFactory = (await ethers.getContractFactory("TestMessageBridge")).connect(deployer);
    const msgBridgeProxy = await upgrades.deployProxy(MessageBridgeFactory, [managementAddress, SENDING_FEE, MAX_MESSAGE_SIZE, MAX_NR_MESSAGES, EXECUTION_WINDOW_SECONDS], { kind: "uups", unsafeAllow: ["constructor", "missing-initializer"], txOverrides: { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS } });
    await msgBridgeProxy.waitForDeployment();
    const msgBridge = await ethers.getContractAt("TestMessageBridge", await msgBridgeProxy.getAddress());

    console.log("\nDeployment of MessageBridge");
    console.log("MessageBridge Proxy: ", await msgBridge.getAddress());
    console.log("MessageBridge Logic: ", await upgrades.erc1967.getImplementationAddress(await msgBridge.getAddress()));

    console.log("\nMessageBridge Configuration");
    console.log("Management Contract:             ", await msgBridge.management());
    console.log("MessageBridge Paused:            ", await msgBridge.messageBridgePaused());
    console.log("MessageBridge Sending Paused:    ", await msgBridge.sendingPaused());
    console.log("MessageBridge Executing Paused:  ", await msgBridge.executingPaused());
    console.log("MessageBridge Sending Fee:       ", await msgBridge.sendingFee());
    console.log("MessageBridge Max Msg Size:      ", await msgBridge.maxMessageSize());
    console.log("MessageBridge Max Nr Messages:   ", await msgBridge.maxNrMessages());
    console.log("MessageBridge Execution Window:  ", await msgBridge.executionWindowSeconds());
    return msgBridge;
}

export async function deployMessageBridgeContracts(): Promise<TestMessageBridge> {
    console.log("\n#####################################################################");
    console.log("################ MessageBridge Contracts Deployment #################");
    console.log("#####################################################################");
    await printNetworkConfiguration();
    printFeeConfiguration();
    console.log("Max Priority Fee Per Gas (gasFeeCap): ", ethers.formatUnits(MAX_PRIORITY_FEE_PER_GAS, "gwei"), "gwei");
    console.log("Max Fee Per Gas (gasTipCap):          ", ethers.formatUnits(MAX_FEE_PER_GAS, "gwei"), "gwei");

    const deployer = getDeployer(ethers.provider);
    const management = await deployBridgeManagement(deployer);
    console.log("Bridge Management deployed at:            ", await management.getAddress());
    const msgBridge = await deployMessageBridge(await management.getAddress(), deployer);
    const executionManager = await deployExecutionManager(deployer, await msgBridge.getAddress());

    // Set the message executor
    const governor = getGovernor(ethers.provider)
    await fundIfLocalNetwork([governor.address], false);
    const tx = await msgBridge.connect(governor).setExecutionManager(await executionManager.getAddress());
    await tx.wait();
    console.log("Message Executor: ", await msgBridge.executionManager());
    return msgBridge;
}

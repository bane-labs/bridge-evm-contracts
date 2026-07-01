// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {console2} from "forge-std/console2.sol";
import {BaseDeploy} from "./BaseDeploy.s.sol";
import {TestBridgeManagement} from "../../contracts/tests/TestBridgeManagement.sol";
import {TestBridge} from "../../contracts/tests/TestBridge.sol";
import {TestMessageBridge} from "../../contracts/tests/TestMessageBridge.sol";
import {ExecutionManager} from "../../contracts/messageBridge/ExecutionManager.sol";

/// @title DeployBridgeSuite
/// @notice Deploys the full bridge stack for a fresh environment in one script.
/// @dev Deploys BridgeManagement, Bridge, MessageBridge, and ExecutionManager,
/// then writes their addresses to the manifest. If GOVERNOR_PRIVATE_KEY is set,
/// the script also broadcasts the governor-only MessageBridge ExecutionManager link.
contract DeployBridgeSuite is BaseDeploy {
    /// @notice Broadcasts the full deployment graph and optionally links ExecutionManager.
    function run() external {
        Roles memory roles = _roles();
        MessageBridgeConfig memory messageConfig = _messageBridgeConfig();
        DeploymentManifest memory manifest;

        console2.log("");
        console2.log("#####################################################################");
        console2.log("################ Bridge Suite Deployment (Foundry) ##################");
        console2.log("#####################################################################");
        console2.log("Network:  ", _deploymentNetwork());
        console2.log("Chain ID: ", block.chainid);

        vm.startBroadcast();
        (TestBridgeManagement management, address managementImplementation) = _deployBridgeManagement(roles);
        (TestBridge bridge, address bridgeImplementation) = _deployBridge(address(management));
        (TestMessageBridge messageBridge, address messageBridgeImplementation) =
            _deployMessageBridge(address(management), messageConfig);
        ExecutionManager executionManager = _deployExecutionManager(address(messageBridge));
        vm.stopBroadcast();

        manifest.bridgeManagement = address(management);
        manifest.bridgeManagementImplementation = managementImplementation;
        manifest.bridge = address(bridge);
        manifest.bridgeImplementation = bridgeImplementation;
        manifest.messageBridge = address(messageBridge);
        manifest.messageBridgeImplementation = messageBridgeImplementation;
        manifest.executionManager = address(executionManager);
        _writeManifest(manifest);

        if (vm.envExists("GOVERNOR_PRIVATE_KEY")) {
            vm.startBroadcast(vm.envUint("GOVERNOR_PRIVATE_KEY"));
            messageBridge.setExecutionManager(address(executionManager));
            vm.stopBroadcast();
            require(
                address(messageBridge.executionManager()) == address(executionManager), "ExecutionManager link failed"
            );
        } else {
            console2.log("");
            console2.log("ExecutionManager not linked.");
            console2.log("Run ConfigureExecutionManager with a governor broadcaster or set GOVERNOR_PRIVATE_KEY.");
        }

        _printBridgeManagement(management, managementImplementation);
        _printBridge(bridge, bridgeImplementation);
        _printMessageBridge(messageBridge, messageBridgeImplementation);
        _printExecutionManager(executionManager);

        console2.log("");
        console2.log("Summary of Deployed Contracts");
        console2.log("BridgeManagement: ", address(management));
        console2.log("Bridge:           ", address(bridge));
        console2.log("MessageBridge:    ", address(messageBridge));
        console2.log("ExecutionManager: ", address(executionManager));
    }
}

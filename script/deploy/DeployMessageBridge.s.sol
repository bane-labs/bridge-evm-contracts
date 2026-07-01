// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseDeploy} from "./BaseDeploy.s.sol";
import {TestMessageBridge} from "../../contracts/tests/TestMessageBridge.sol";

/// @title DeployMessageBridge
/// @notice Deploys and initializes the MessageBridge proxy.
/// @dev Requires BridgeManagement to exist in the deployment manifest and reads
/// message bridge limits and fees from optional MESSAGE_BRIDGE_* environment variables.
contract DeployMessageBridge is BaseDeploy {
    /// @notice Broadcasts MessageBridge implementation and proxy deployment.
    function run() external {
        DeploymentManifest memory manifest = _loadManifest();
        require(manifest.bridgeManagement != address(0), "Deploy BridgeManagement first");

        vm.startBroadcast();
        (TestMessageBridge messageBridge, address implementation) =
            _deployMessageBridge(manifest.bridgeManagement, _messageBridgeConfig());
        vm.stopBroadcast();

        manifest.messageBridge = address(messageBridge);
        manifest.messageBridgeImplementation = implementation;
        _writeManifest(manifest);
        _printMessageBridge(messageBridge, implementation);
    }
}

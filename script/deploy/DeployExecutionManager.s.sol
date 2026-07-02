// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseDeploy} from "./BaseDeploy.s.sol";
import {ExecutionManager} from "../../contracts/messageBridge/ExecutionManager.sol";

/// @title DeployExecutionManager
/// @notice Deploys ExecutionManager for an existing MessageBridge.
/// @dev Requires MessageBridge to exist in the deployment manifest. This script
/// only deploys ExecutionManager; run ConfigureExecutionManager afterwards to link it.
contract DeployExecutionManager is BaseDeploy {
    /// @notice Broadcasts ExecutionManager deployment and records it in the manifest.
    function run() external {
        DeploymentManifest memory manifest = _loadManifest();
        require(manifest.messageBridge != address(0), "Deploy MessageBridge first");

        vm.startBroadcast();
        ExecutionManager executionManager = _deployExecutionManager(manifest.messageBridge);
        vm.stopBroadcast();

        manifest.executionManager = address(executionManager);
        _writeManifest(manifest);
        _printExecutionManager(executionManager);
    }
}

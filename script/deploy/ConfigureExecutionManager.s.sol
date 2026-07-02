// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseDeploy} from "./BaseDeploy.s.sol";
import {TestMessageBridge} from "../../contracts/tests/TestMessageBridge.sol";

/// @title ConfigureExecutionManager
/// @notice Links an already deployed MessageBridge proxy to its ExecutionManager.
/// @dev MessageBridge restricts this configuration to the governor role. Use this
/// script after deploying MessageBridge and ExecutionManager separately, or after
/// DeployBridgeSuite when the suite was run without GOVERNOR_PRIVATE_KEY.
contract ConfigureExecutionManager is BaseDeploy {
    /// @notice Reads messageBridge and executionManager from the deployment manifest
    /// and broadcasts the governor-only setExecutionManager call.
    function run() external {
        DeploymentManifest memory manifest = _loadManifest();
        require(manifest.messageBridge != address(0), "MessageBridge missing");
        require(manifest.executionManager != address(0), "ExecutionManager missing");

        TestMessageBridge messageBridge = TestMessageBridge(payable(manifest.messageBridge));

        if (vm.envExists("GOVERNOR_PRIVATE_KEY")) _startGovernorBroadcast(messageBridge.management().getGovernor());
        else vm.startBroadcast();

        messageBridge.setExecutionManager(manifest.executionManager);
        vm.stopBroadcast();

        require(address(messageBridge.executionManager()) == manifest.executionManager, "ExecutionManager link failed");
    }
}

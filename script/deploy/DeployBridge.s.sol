// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseDeploy} from "./BaseDeploy.s.sol";
import {TestBridge} from "../../contracts/tests/TestBridge.sol";

/// @title DeployBridge
/// @notice Deploys and initializes the native/token Bridge proxy.
/// @dev Requires BridgeManagement to exist in the deployment manifest because the
/// Bridge initializer stores the management contract address.
contract DeployBridge is BaseDeploy {
    /// @notice Broadcasts Bridge implementation and proxy deployment.
    function run() external {
        DeploymentManifest memory manifest = _loadManifest();
        require(manifest.bridgeManagement != address(0), "Deploy BridgeManagement first");

        vm.startBroadcast();
        (TestBridge bridge, address implementation) = _deployBridge(manifest.bridgeManagement);
        vm.stopBroadcast();

        manifest.bridge = address(bridge);
        manifest.bridgeImplementation = implementation;
        _writeManifest(manifest);
        _printBridge(bridge, implementation);
    }
}

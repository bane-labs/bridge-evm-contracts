// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseDeploy} from "./BaseDeploy.s.sol";
import {TestBridgeManagement} from "../../contracts/tests/TestBridgeManagement.sol";

/// @title DeployBridgeManagement
/// @notice Deploys and initializes the BridgeManagement proxy.
/// @dev Reads role addresses from environment variables and writes the proxy and
/// implementation addresses to the deployment manifest for dependent scripts.
contract DeployBridgeManagement is BaseDeploy {
    /// @notice Broadcasts BridgeManagement implementation and proxy deployment.
    function run() external {
        Roles memory roles = _roles();
        DeploymentManifest memory manifest = _loadManifest();

        vm.startBroadcast();
        (TestBridgeManagement management, address implementation) = _deployBridgeManagement(roles);
        vm.stopBroadcast();

        manifest.bridgeManagement = address(management);
        manifest.bridgeManagementImplementation = implementation;
        manifest = _clearContractsDependingOnBridgeManagement(manifest);
        _writeManifest(manifest);
        _printBridgeManagement(management, implementation);
    }
}

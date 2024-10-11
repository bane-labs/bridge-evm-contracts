// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./InitializationLib.sol";
import "./../interfaces/ITestBridgeManagement.sol";
import "../../management/BridgeManagementImplV1ToV2.sol";

/// @custom:oz-upgrades-from TestBridgeManagement
contract TestManagementV1ToV2 is BridgeManagementImplV1ToV2 {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeManagementImplV1ToV2() {}

    // Authorize the contract owner to upgrade the contract for testing purposes.
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}

    function upgradeToV2() external override reinitializer(2) onlyOwner {
        _upgradeToV2();
    }

    // The following code is just for verifying the initialized state of the contract

    function getCurrentInitializedVersion() external view returns (uint256) {
        return InitializationLib._getInitializableStorageValue()._initialized;
    }
}

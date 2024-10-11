// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./BridgeManagementImpl.sol";

/// @custom:oz-upgrades-from BridgeManagementImpl
contract BridgeManagementImplV1ToV2 is BridgeManagementImpl {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeManagementImpl() {}

    function upgradeToV2() external virtual reinitializer(2) onlyAdmin {
        _upgradeToV2();
    }

    function _upgradeToV2() internal onlyInitializing {
        // Set validators in new version
        uint256 validatorsLength = validators.length;
        for (uint256 i = 0; i < validatorsLength; i++) {
            address validator = validators[i];
            validatorMap[validator] = true;
        }
        // Todo: Implement reinitialization logic
    }
}

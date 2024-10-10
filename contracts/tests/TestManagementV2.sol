// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../management/BridgeManagementImplV1ToV2.sol";

contract TestManagementV2 is BridgeManagementImplV1ToV2 {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeManagementImplV1ToV2() {}

    // Authorize the contract owner to upgrade the contract for testing purposes.
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}
}

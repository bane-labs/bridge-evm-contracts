// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../management/BridgeManagementImpl.sol";

contract TestBridgeManagement is BridgeManagementImpl {
    // Authorize the contract owner to upgrade the contract for testing purposes.
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./BridgeManagementImpl.sol";

contract BridgeManagementImplV1ToV2 is BridgeManagementImpl {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeManagementImpl() {}

    function reinitialize() public reinitializer(2) {
        // Todo: Implement reinitialization logic
    }
}

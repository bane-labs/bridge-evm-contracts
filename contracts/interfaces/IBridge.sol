// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";

interface IBridge {
    // General bridge events

    event BridgeLock();
    event BridgeUnlock();
    event Fund(uint256 amount);

    // General bridge functions

    function lockBridge() external;

    function unlockBridge() external;
}

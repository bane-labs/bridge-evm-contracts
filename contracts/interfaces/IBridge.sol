// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";

interface IBridge {
    // General bridge events

    event BridgePause();
    event BridgeUnpause();
    event PendingPeriodChange(uint256 pendingPeriod);
    event ExecutionWindowChange(uint256 executionWindow);
    event Fund(uint256 amount);

    // General bridge functions

    function pauseBridge() external;

    function unpauseBridge() external;

    function setPendingPeriod(uint256 pendingPeriod) external;

    function setExecutionWindow(uint256 executionWindow) external;
}

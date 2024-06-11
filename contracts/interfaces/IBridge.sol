// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";

interface IBridge {
    // General bridge events

    event BridgePause();
    event BridgeUnpause();
    event FeeChangePendingPeriodChange(uint256 pendingPeriod);
    event FeeChangeExecutionWindowChange(uint256 executionWindow);
    event Fund(uint256 amount);

    // General bridge functions

    function pauseBridge() external;

    function unpauseBridge() external;

    function setFeeChangePendingPeriod(uint256 pendingPeriod) external;

    function setFeeChangeExecutionWindow(uint256 executionWindow) external;
}

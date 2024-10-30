// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../library/BridgeLib.sol";

interface IBridge {
    // General bridge events

    event BridgePause();
    event BridgeUnpause();
    event Fund(uint256 amount);
    event WithdrawalPause();
    event WithdrawalUnpause();

    // General bridge functions

    function pauseBridge() external;

    function unpauseBridge() external;

    function pauseWithdrawals() external;

    function unpauseWithdrawals() external;
}

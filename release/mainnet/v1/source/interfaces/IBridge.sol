// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../library/BridgeLib.sol";

interface IBridge {
    // General bridge events

    event BridgePause();
    event BridgeUnpause();
    event Fund(uint256 amount);

    // General bridge functions

    function pauseBridge() external;

    function unpauseBridge() external;
}

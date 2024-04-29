// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";

interface IBridge {
    // General bridge events

    event Locked();
    event Unlocked();
    event Funded(uint256 amount);

    // General bridge functions

    function lock() external;

    function unlock() external;
}

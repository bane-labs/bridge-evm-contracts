// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";

interface IBridge {
    // General bridge events

    event Lock();
    event Unlock();
    event Fund(uint256 amount);

    // General bridge functions

    function lock() external;

    function unlock() external;
}

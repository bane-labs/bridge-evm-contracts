// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/ManagementLib.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BridgeManagementStorageV1 {
    // Slots 0-99 remain empty for future upgrades (if further storage extension is needed, e.g., similar to ReentrancyGuard's _status var, this contract can easily be extended and the new var can use the next slot from _gap0, so that the other storage variables can remain in this file)
    uint256[100] private _gap0;

    // Slot 100
    address internal owner;

    // Slot 101
    address internal relayer;

    // Slot 102
    uint256 internal validatorThreshold;

    // Slot 103 - in slot 103 the size of the address array is stored. The first value is stored at keccak256(uint256(104)) and the rest are stored in subsequent slots.
    address[] internal validators;

    // Slot 104
    address internal governor;

    // Slot 105
    address internal securityGuard;

    // Slot 106
    address internal funder;
}

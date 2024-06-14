// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/ManagementLib.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BridgeManagementStorageV1 {
    // Slots 0-99 remain empty for future upgrades
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

    // Slots 107-199 remain empty for future upgrades - these remain empty anyway. This is just here to make sure of it if this contract were extended.
    uint256[93] private _gap1;
}

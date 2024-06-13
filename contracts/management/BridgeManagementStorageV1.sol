// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/ManagementLib.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BridgeManagementStorageV1 {
    // Slots 0-100 remain empty for future upgrades
    uint256[101] private _gap0_100;

    // Slot 101
    address internal owner;

    // Slot 102
    address internal relayer;

    // Slot 103
    uint256 internal validatorThreshold;

    // Slot 104 - in slot 104 the size of the address array is stored. The first value is stored at keccak256(uint256(104)) and the rest are stored in subsequent slots.
    address[] internal validators;

    // Slot 105
    address internal governor;

    // Slot 106
    address internal securityGuard;

    // Slot 107
    address internal funder;

    // Slots 108-200 remain empty for future upgrades - these remain empty anyway. This is just here to make sure of it if this contract were extended.
    uint256[93] private _gap108_200;
}

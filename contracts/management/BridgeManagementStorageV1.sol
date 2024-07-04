// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/ManagementLib.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract BridgeManagementStorageV1 is Ownable2Step {
    // Slot 0 is taken by Ownable2Step's _owner storage value
    // Slot 1 is taken by Ownable2Step's _pendingOwner storage value
    // Slots 2-99 remain empty for future upgrades (if further storage extension is needed, e.g., similar to ReentrancyGuard's _status var, this contract can easily be extended and the new var can use the next slot from _gap0, so that the other storage variables can remain in this file)
    uint256[98] private _gap0;

    // Slot 100
    address internal relayer;

    // Slot 101
    uint256 internal validatorThreshold;

    // Slot 102 - in slot 102 the size of the address array is stored. The first value is stored at keccak256(uint256(104)) and the rest are stored in subsequent slots.
    address[] internal validators;

    // Slot 103
    address internal governor;

    // Slot 104
    address internal securityGuard;

    // Slot 105
    address internal funder;

    constructor(address initialOwner) Ownable(initialOwner) {}
}

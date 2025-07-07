// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "../interfaces/IBridgeManagement.sol";
import "../library/StorageTypes.sol";

/**
 * @title BridgeStorageV1
 * @author BaneLabs
 * @dev This contract holds the storage variables for the Bridge contract and outlines the slot allocations of the contracts storage. Storage slot modifications should be done with care to avoid conflicts with existing storage slots in the proxy.
 */
abstract contract BridgeStorageV1 is ReentrancyGuardUpgradeable {
    // Slots 0-99 remain empty for future upgrades (if further storage extension is needed, e.g., similar to ReentrancyGuard's _status var, this contract can easily be extended and the new var can use the next slot from _gap0, so that the other storage variables can remain in this file)
    uint256[100] private _gap0;

    // Slot 100
    IBridgeManagement public management;
    // Slot 100 - offset 20
    bool public bridgePaused;
    // Slot 100 - offset 21
    bool public withdrawalsPaused;
    // Slot 101
    uint256 public unclaimedRewards;
    // Slot 102
    mapping(uint256 nonce => StorageTypes.Claimable claimable) public claimableNative;
    // Slot 103
    mapping(address tokenAddress => StorageTypes.TokenBridge tokenBridge) public tokenBridges;
    // Slot 104
    mapping(address tokenAddress => mapping(uint256 nonce => StorageTypes.Claimable claimable) claimableTokens) public
        tokenClaimables;

    // Deprecated in V3 (slots will be cleared in V3 reinitialization)
    // Slots 105-113 (9 slots)
    StorageTypes.NativeBridgeV2 public nativeBridgeV2;

    // Slot 114
    address[] public registeredTokens;

    // Slot 115
    StorageTypes.NativeBridgeV3 public nativeBridge;

    // commented until a reinitialization is needed
    // function _upgradeToV<version_nr>() internal onlyInitializing {
    // }
}

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

    // Deprecated slots in V3 - deleted in v3 upgrade
    // Slots 105-113 (9 slots)
    uint256[9] private _gap1;

    // Slot 114
    address[] public registeredTokens;

    // Slot 115
    StorageTypes.NativeBridge public nativeBridge;

    // Slot 125 - 132 (8 slots)
    // struct MessageBridge {
    //     bool paused;             // slot 125
    //     State n3ToEvmState;      // slots 126-127
    //     State evmToN3State;      // slots 128-129
    //     MessageConfig config;    // slots 130-132
    // }
    StorageTypes.MessageBridge public messageBridge;

    // Slot 133
    mapping(uint256 => bytes) public n3ToEvmRawMessages;

    // Slot 118
    mapping(uint256 => StorageTypes.Metadata) public n3ToEvmMetadata;

    // commented until a reinitialization is needed
    // function _upgradeToV<version_nr>() internal onlyInitializing {
    // }
}

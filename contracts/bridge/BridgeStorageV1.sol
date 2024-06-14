// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeManagement.sol";
import "../library/StorageTypes.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BridgeStorageV1
 * @author BaneLabs
 * @dev This contract holds the storage variables for the Bridge contract and outlines the slot allocations of the contracts storage. Storage slot modifications should be done with care to avoid conflicts with existing storage slots in the proxy.
 */
contract BridgeStorageV1 is ReentrancyGuard {
    // Slot 0 is taken by ReentrancyGuard's _status storage value
    // Slots 1-99 remain empty for future upgrades
    uint256[99] private _gap0;

    // Slot 100
    IBridgeManagement public management;
    // Slot 100 - offset 20
    bool public bridgePaused;
    // Slot 102
    uint256 public unclaimedRewards;
    // Slot 103
    uint256 public pendingPeriod;
    // Slot 104
    uint256 public executionWindow;

    // Slots 105-199 (95 slots)
    uint256[95] private _gap1;

    // Slot 200
    mapping(uint256 nonce => StorageTypes.Claimable claimable)
        public claimableGas;

    // Slot 201
    mapping(address tokenAddress => StorageTypes.TokenBridge tokenBridge)
        public tokenBridges;
    // Slot 202
    mapping(address tokenAddress => mapping(uint256 nonce => StorageTypes.Claimable claimable) claimableTokens)
        public tokenClaimables;
    // Slot 203
    mapping(address tokenAddress => StorageTypes.Change change)
        public tokenBridgeChanges;

    // Slots 204-213 (10 slots)
    StorageTypes.GasBridge public gasBridge;

    constructor(address _management) {
        management = IBridgeManagement(_management);
        gasBridge = StorageTypes.GasBridge({
            paused: false,
            depositState: StorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: StorageTypes.State({nonce: 0, root: 0x0}),
            config: StorageTypes.GasConfig({
                fee: 1e17,
                minAmount: 1e18,
                maxAmount: 1e22,
                maxDeposits: 100
            })
        });
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeManagement.sol";
import "../library/StorageTypes.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SlotShiftV1
 * @author BaneLabs
 * @dev This contract shifts the storage slots by 100 of any extending contract - making room for future upgrades.
 */
contract SlotShiftV1 {
    // Slots 0-99 remain empty for future upgrades
    uint256[100] private _gap0_99;
}

/**
 * @title BridgeStorageV1
 * @author BaneLabs
 * @dev This contract holds the storage variables for the Bridge contract and outlines the slot allocations of the contracts storage. Storage slot modifications should be done with care to avoid conflicts with existing storage slots in the proxy.
 */
contract BridgeStorageV1 is SlotShiftV1, ReentrancyGuard {
    // Slots 0-99 are taken by SlotShiftV1 (SlotShiftV1 has 100 empty slots)
    // Slot 100 is taken by ReentrancyGuard's _status storage value
    // Slots 101-199 remain empty for future upgrades
    uint256[99] private _gap101_200;

    // ###############################
    // Contract-wide storage variables
    // ###############################

    // Slot 200
    IBridgeManagement public management;
    // Slot 200 - offset 20
    bool public bridgePaused;
    // Slot 201
    uint256 public unclaimedRewards;
    // Slots 202-299 remain empty for future upgrades
    uint256[98] private _gap202_299;

    // ####################################
    // GasBridge-specific storage variables
    // ####################################

    // Slot 300
    mapping(uint256 nonce => StorageTypes.Claimable claimable)
        public claimableGas;
    // Slots 301-310 (10 slots)
    StorageTypes.GasBridge public gasBridge;
    // Slots 311-399 remain empty for future upgrades
    uint256[89] private _gap311_399;

    // ######################################
    // TokenBridge-specific storage variables
    // ######################################

    // Slot 400
    mapping(address tokenAddress => StorageTypes.TokenBridge tokenBridge)
        public tokenBridges;
    // Slot 401
    mapping(address tokenAddress => mapping(uint256 nonce => StorageTypes.Claimable claimable) claimableTokens)
        public tokenClaimables;

    // Slot 402-499 remain empty for future upgrades - these remain empty anyway. This is just here to make sure of it if this contract were extended.
    uint256[97] private _gap402_499;

    constructor(address _management) {
        management = IBridgeManagement(_management);
        gasBridge = StorageTypes.GasBridge({
            depositState: StorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: StorageTypes.State({nonce: 0, root: 0x0}),
            config: StorageTypes.GasConfig({
                fee: 1e17,
                minAmount: 1e18,
                maxAmount: 1e22,
                maxDeposits: 100,
                paused: false,
                gap: [uint256(0), uint256(0)]
            })
        });
    }
}

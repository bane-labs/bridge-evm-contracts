// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeManagement.sol";
import "../library/StorageTypes.sol";

contract BridgeStorageV1 {
    IBridgeManagement public management;

    bool public bridgePaused;

    StorageTypes.GasBridge public gasBridge;
    mapping(uint256 nonce => StorageTypes.Claimable claimable)
        public claimableGas;

    uint256 public unclaimedRewards;

    mapping(address tokenAddress => StorageTypes.TokenBridge tokenBridge)
        public tokenBridges;
    mapping(address tokenAddress => mapping(uint256 nonce => StorageTypes.Claimable claimable) claimableTokens)
        public tokenClaimables;

    uint256 public feeChangePendingPeriod;
    uint256 public feeChangeExecutionWindow;
}

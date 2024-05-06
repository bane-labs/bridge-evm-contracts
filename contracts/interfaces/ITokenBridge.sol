// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";
import "../library/StorageTypes.sol";

interface ITokenBridge {
    // Token bridge events
    event TokenRegister(
        uint256 indexed id,
        StorageTypes.TokenType tokenType,
        StorageTypes.TokenConfig tokenConfig
    );
    event TokenUnregister(uint256 indexed id);
    event TokenLock(uint256 indexed id);
    event TokenUnlock(uint256 indexed id);
    event TokenMinWithdrawalAmountChange(uint256 indexed id, uint256 minAmount);
    event TokenMaxWithdrawalAmountChange(uint256 indexed id, uint256 maxAmount);
    event TokenTypeConfigChange(
        StorageTypes.TokenType tokenType,
        StorageTypes.TokenTypeConfig tokenTypeConfig
    );
    event TokenDeposit(
        uint256 indexed id,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );
    event TokenWithdrawal(
        uint256 indexed id,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );
    event TokenClaimable(
        uint256 indexed id,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );
    event TokenClaim(
        uint256 indexed id,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );

    // Token bridge functions

    function registerToken(
        uint256 id,
        StorageTypes.TokenType tokenType,
        StorageTypes.TokenConfig calldata tokenConfig
    ) external;

    function unregisterToken(uint256 id) external;

    function lockToken(uint256 id) external;

    function unlockToken(uint256 id) external;

    function setTokenWithdrawalMinAmount(uint id, uint256 minAmount) external;

    function setTokenWithdrawalMaxAmount(
        uint256 id,
        uint256 maxAmount
    ) external;

    function setTokenTypeConfig(
        StorageTypes.TokenType tokenType,
        StorageTypes.TokenTypeConfig calldata tokenTypeConfig
    ) external;

    function depositToken(
        uint256 id,
        BridgeLib.DepositData[] calldata deposits,
        bytes32 depositRoot,
        BridgeLib.Signature[] calldata signatures
    ) external;

    function claimToken(uint256 id, uint256 nonce) external;

    function withdrawToken(uint256 amount, address to) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";
import "../library/BridgeStorageTypes.sol";

interface ITokenBridge {
    // Token bridge events
    event TokenRegister(
        uint256 indexed identifier,
        BridgeStorageTypes.TokenType tokenType,
        BridgeStorageTypes.TokenConfig tokenConfig
    );
    event TokenUnregister(uint256 indexed identifier);
    event TokenLock(uint256 indexed identifier);
    event TokenUnlock(uint256 indexed identifier);
    event TokenWithdrawalMinAmountChanged(
        uint256 indexed identifier,
        uint256 minAmount
    );
    event TokenWithdrawalMaxAmountChanged(
        uint256 indexed identifier,
        uint256 maxAmount
    );
    event TokenDeposit(
        uint256 indexed identifier,
        uint256 amount,
        address indexed to
    );
    event TokenWithdrawal(
        uint256 indexed identifier,
        uint256 amount,
        address indexed to
    );
    event TokenClaimable(
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );
    event TokenClaim(uint256 indexed nonce, uint256 amount, address indexed to);

    // Token bridge functions

    function registerTokenBridge(
        uint256 identifier,
        BridgeStorageTypes.TokenType tokenType,
        BridgeStorageTypes.TokenConfig calldata tokenConfig
    ) external;

    function unregisterTokenBridge(uint256 identifier) external;

    function lockTokenBridge(uint256 identifier) external;

    function unlockTokenBridge(uint256 identifier) external;

    function setTokenWithdrawalMinAmount(
        uint identifier,
        uint256 minAmount
    ) external;

    function setTokenWithdrawalMaxAmount(
        uint256 identifier,
        uint256 maxAmount
    ) external;

    function deposit(
        uint256 identifier,
        BridgeLib.DepositData[] calldata deposits,
        bytes32 depositRoot,
        BridgeLib.Signature[] calldata signatures
    ) external;

    function claim(
        uint256 identifier,
        uint256 nonce,
        uint256 amount,
        address to
    ) external;

    function withdraw(uint256 identifier, uint256 amount, address to) external;

    function claim(uint256 identifier, uint256 nonce) external;
}

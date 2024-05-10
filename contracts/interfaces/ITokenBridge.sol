// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";
import "../library/StorageTypes.sol";

interface ITokenBridge {
    // Token bridge events
    event TokenRegister(
        address indexed neoXTokenAddress,
        StorageTypes.TokenType tokenType,
        StorageTypes.TokenConfig tokenConfig
    );
    event TokenUnregister(
        address indexed neoXTokenAddress,
        address indexed neoN3TokenAddress
    );
    event TokenLock(
        address indexed neoXTokenAddress,
        address indexed neoN3TokenAddress
    );
    event TokenUnlock(
        address indexed neoXTokenAddress,
        address indexed neoN3TokenAddress
    );
    event TokenMinWithdrawalAmountChange(
        address indexed neoXTokenAddress,
        uint256 minAmount
    );
    event TokenMaxWithdrawalAmountChange(
        address indexed neoXTokenAddress,
        uint256 maxAmount
    );
    event TokenTypeConfigChange(
        StorageTypes.TokenType tokenType,
        StorageTypes.TokenTypeConfig tokenTypeConfig
    );
    event TokenDeposit(
        address indexed neoXTokenAddress,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );
    event TokenWithdrawal(
        address indexed neoXTokenAddress,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );
    event TokenClaimable(
        address indexed neoXTokenAddress,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );
    event TokenClaim(
        address indexed neoXTokenAddress,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );

    // Token bridge functions

    function registerToken(
        address neoXTokenAddress,
        StorageTypes.TokenType tokenType,
        StorageTypes.TokenConfig calldata tokenConfig
    ) external;

    function unregisterToken(address neoXTokenAddress) external;

    function lockToken(address neoXTokenAddress) external;

    function unlockToken(address neoXTokenAddress) external;

    function setTokenWithdrawalMinAmount(
        address neoXTokenAddress,
        uint256 minAmount
    ) external;

    function setTokenWithdrawalMaxAmount(
        address neoXTokenAddress,
        uint256 maxAmount
    ) external;

    function setTokenTypeConfig(
        StorageTypes.TokenType tokenType,
        StorageTypes.TokenTypeConfig calldata tokenTypeConfig
    ) external;

    function depositToken(
        address neoXTokenAddress,
        BridgeLib.DepositData[] calldata deposits,
        bytes32 depositRoot,
        BridgeLib.Signature[] calldata signatures
    ) external;

    function claimToken(address neoXTokenAddress, uint256 nonce) external;

    function withdrawToken(uint256 amount, address to) external payable;
}

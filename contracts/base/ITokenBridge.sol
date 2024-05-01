// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";
import "../library/BridgeStorageTypes.sol";

interface ITokenBridge {
    // Token bridge events
    event NewClaimable(
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );
    event Claim(uint256 indexed nonce, uint256 amount, address indexed to);
    event TokenBridgeLock(uint256 indexed identifier);
    event TokenBridgeUnlock(uint256 indexed identifier);
    event TokenBridgeRegister(
        uint256 indexed identifier,
        BridgeStorageTypes.TokenType tokenType,
        BridgeStorageTypes.TokenConfig tokenConfig
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

    // Token bridge functions

    function registerTokenBridge(
        uint256 identifier,
        BridgeStorageTypes.TokenType tokenType,
        BridgeStorageTypes.TokenConfig calldata tokenConfig
    ) external;

    function unregisterTokenBridge(uint256 identifier) external;

    function lockTokenBridge(uint256 identifier) external;

    function unlockTokenBridge(uint256 identifier) external;

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
}

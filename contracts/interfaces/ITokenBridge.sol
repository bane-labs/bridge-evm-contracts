// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";
import "../library/StorageTypes.sol";

interface ITokenBridge {
    event TokenRegister(
        address indexed neoXToken,
        StorageTypes.TokenConfig tokenConfig
    );
    event TokenUnregister(
        address indexed neoXToken,
        address indexed neoN3Token
    );
    event TokenBridgePause(
        address indexed neoXToken,
        address indexed neoN3Token
    );
    event TokenBridgeUnpause(
        address indexed neoXToken,
        address indexed neoN3Token
    );
    event TokenDeposit(
        address indexed neoXToken,
        uint256 indexed nonce,
        address indexed to,
        uint256 amount
    );
    event TokenDepositRootUpdate(
        address indexed neoXToken,
        address indexed neoN3Token,
        uint256 indexed nonce,
        bytes32 depositRoot
    );
    event TokenClaimable(
        address indexed neoXToken,
        uint256 indexed nonce,
        address indexed to,
        uint256 amount
    );
    event TokenClaim(
        address indexed neoXToken,
        uint256 indexed nonce,
        address indexed to,
        uint256 amount
    );
    event TokenParamChangeInitiation(
        address indexed neoXToken,
        StorageTypes.ParamType indexed paramType,
        uint256 value
    );
    event TokenParamChange(
        address indexed neoXToken,
        StorageTypes.ParamType indexed paramType,
        uint256 value
    );
    event TokenWithdrawal(
        address indexed neoXToken,
        address neoN3Token,
        uint256 indexed nonce,
        address indexed to,
        uint256 amount,
        address from,
        bytes32 withdrawalHash,
        bytes32 withdrawalRoot
    );

    function registerToken(
        address neoXToken,
        StorageTypes.TokenConfig calldata tokenConfig
    ) external;

    function unregisterToken(address neoXToken) external;

    function pauseTokenBridge(address neoXToken) external;

    function unpauseTokenBridge(address neoXToken) external;

    function depositToken(
        address neoXToken,
        bytes32 tokenDepositRoot,
        BridgeLib.Signature[] calldata signatures,
        BridgeLib.DepositData[] calldata deposits
    ) external;

    function claimToken(address neoXToken, uint256 nonce) external;

    function withdrawToken(
        address neoXToken,
        address to,
        uint256 amount
    ) external payable;

    function initiateTokenParamChanges(
        address[] calldata neoXTokens,
        StorageTypes.ParamType[] calldata paramTypes,
        uint256[] calldata values
    ) external;

    function executeTokenParamChanges(address[] calldata neoXTokens) external;
}

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
    event TokenWithdrawalFeeChange(address indexed neoXToken, uint256 fee);
    event MinTokenWithdrawalAmountChange(
        address indexed neoXToken,
        uint256 minAmount
    );
    event MaxTokenWithdrawalAmountChange(
        address indexed neoXToken,
        uint256 maxAmount
    );
    event MaxTokenDepositsChange(
        address indexed neoXToken,
        uint256 maxDeposits
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

    function setTokenWithdrawalFee(
        address[] calldata neoXTokens,
        uint256[] calldata fees
    ) external;

    function setMinTokenWithdrawalAmount(
        address[] calldata neoXTokens,
        uint256[] calldata minAmounts
    ) external;

    function setMaxTokenWithdrawalAmount(
        address[] calldata neoXTokens,
        uint256[] calldata maxAmounts
    ) external;

    function setMaxTokenDeposits(
        address[] calldata neoXTokens,
        uint256[] calldata maxWithdrawals
    ) external;
}

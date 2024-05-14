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
    event TokenPause(address indexed neoXToken, address indexed neoN3Token);
    event TokenUnpause(address indexed neoXToken, address indexed neoN3Token);
    event TokenDeposit(
        address indexed neoXToken,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );
    event TokenClaimable(
        address indexed neoXToken,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );
    event TokenClaim(
        address indexed neoXToken,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
    );
    event TokenWithdrawal(
        address indexed neoXToken,
        uint256 indexed nonce,
        uint256 amount,
        address indexed to
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
        address _neoXToken,
        StorageTypes.TokenConfig calldata _tokenConfig
    ) external;

    function unregisterToken(address neoXToken) external;

    function pauseTokenBridge(address neoXToken) external;

    function unpauseTokenBridge(address neoXToken) external;

    function depositToken(
        address _neoXToken,
        bytes32 _tokenDepositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    ) external;

    function claimToken(address neoXToken, uint256 nonce) external;

    function withdrawToken(address to, uint256 amount) external payable;

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

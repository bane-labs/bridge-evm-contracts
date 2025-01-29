// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../library/BridgeLib.sol";

interface INativeBridge {
    event NativeBridgePause();
    event NativeBridgeUnpause();
    event NativeDeposit(uint256 indexed nonce, address indexed to, uint256 amount);
    event NativeDepositRootUpdate(uint256 indexed nonce, bytes32 depositRoot);
    event NativeClaimable(uint256 indexed nonce, address indexed to, uint256 amount);
    event NativeClaim(uint256 indexed nonce, address indexed to, uint256 amount);
    event NativeWithdrawal(
        uint256 indexed nonce,
        address indexed to,
        uint256 amount,
        address from,
        bytes32 withdrawalHash,
        bytes32 withdrawalRoot
    );
    event NativeWithdrawalFeeChange(uint256 newFee);
    event MinNativeWithdrawalChange(uint256 newAmount);
    event MaxNativeWithdrawalChange(uint256 amount);
    event MaxNativeDepositsChange(uint256 amount);

    function setNativeBridge(
        uint256 _fee,
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _maxDeposits,
        uint256 _decimalsHere,
        uint256 _decimalsOnN3
    )
        external;

    function pauseNativeBridge() external;

    function unpauseNativeBridge() external;

    function depositNative(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    )
        external;

    function claimNative(uint256 _nonce) external;

    function withdrawNative(address _to, uint256 _maxFee) external payable;

    function setNativeWithdrawalFee(uint256 _fee) external;

    function setMinNativeWithdrawalAmount(uint256 _amount) external;

    function setMaxNativeWithdrawalAmount(uint256 _amount) external;

    function setMaxNativeDeposits(uint256 _maxNrDeposits) external;
}

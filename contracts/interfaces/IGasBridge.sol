// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";

interface IGasBridge {
    event GasBridgePause();
    event GasBridgeUnpause();
    event GasDeposit(uint256 indexed nonce, address indexed to, uint256 amount);
    event GasDepositRootUpdate(uint256 indexed nonce, bytes32 depositRoot);
    event GasClaimable(
        uint256 indexed nonce,
        address indexed to,
        uint256 amount
    );
    event GasClaim(uint256 indexed nonce, address indexed to, uint256 amount);
    event GasWithdrawal(
        uint256 indexed nonce,
        address indexed to,
        uint256 amount,
        address from,
        bytes32 withdrawalHash,
        bytes32 withdrawalRoot
    );
    event GasWithdrawalFeeChange(uint256 newFee);
    event MinGasWithdrawalChange(uint256 newAmount);
    event MaxGasWithdrawalChange(uint256 amount);
    event MaxGasDepositsChange(uint8 amount);

    function pauseGasBridge() external;

    function unpauseGasBridge() external;

    function depositGas(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    ) external;

    function claimGas(uint256 _nonce) external;

    function withdrawGas(address _to) external payable;

    function setGasWithdrawalFee(uint256 _fee) external;

    function setMinGasWithdrawalAmount(uint256 _amount) external;

    function setMaxGasWithdrawalAmount(uint256 _amount) external;

    function setMaxGasDeposits(uint8 _maxNrDeposits) external;
}

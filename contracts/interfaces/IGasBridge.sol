// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";
import "../library/StorageTypes.sol";

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
    event GasParamChange(
        StorageTypes.ParamType indexed paramType,
        uint256 value
    );
    event GasParamChangeInitiation(
        StorageTypes.ParamType indexed paramType,
        uint256 value
    );

    function pauseGasBridge() external;

    function unpauseGasBridge() external;

    function depositGas(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    ) external;

    function claimGas(uint256 _nonce) external;

    function withdrawGas(address _to) external payable;

    function initiateGasParamChange(
        StorageTypes.ParamType _paramType,
        uint256 _value
    ) external;

    function executeGasParamChange() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";

interface IGasBridge {
    // Gas-related events
    event GasDeposit(uint256 nonce, uint256 amount, address to);
    event GasClaimable(uint256 nonce, uint256 amount, address to);
    event GasClaim(uint256 nonce, uint256 amount, address to);
    event GasWithdrawal(
        uint256 nonce,
        uint256 amount,
        address to,
        address from,
        bytes32 withdrawalHash,
        bytes32 withdrawalRoot
    );
    event GasWithdrawalFeeChange(uint256 newFee);
    event MinGasWithdrawalChange(uint256 newAmount);
    event MaxGasWithdrawalChange(uint256 amount);
    event MaxGasDepositsPerDistributionChange(uint8 amount);

    // Gas-related functions

    function depositGas(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    ) external;

    function claimGas(uint256 _nonce) external;

    function withdrawGas(address _to) external payable;

    function setGasWithdrawalFee(uint256 _fee) external;

    function setGasWithdrawalMinAmount(uint256 _amount) external;

    function setGasWithdrawalMaxAmount(uint256 _amount) external;

    function setGasMaxNrDepositsPerDistribution(uint8 _maxNrDeposits) external;
}

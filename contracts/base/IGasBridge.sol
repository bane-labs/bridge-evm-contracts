// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";

interface IGasBridge {
    // Gas-related events
    event Deposit(uint64 nonce, uint64 amount, address to);
    event Claimable(uint64 nonce, uint64 amount, address to);
    event Claimed(uint64 nonce, uint64 amount, address to);
    event Withdrawal(
        uint64 nonce,
        uint64 amount,
        address to,
        address from,
        bytes32 withdrawalHash,
        bytes32 withdrawalRoot
    );
    event WithdrawalFeeChanged(uint256 newFee);
    event MinWithdrawalAmountChanged(uint256 newAmount);
    event MaxWithdrawalAmountChanged(uint256 amount);
    event MaxDepositsPerDistributionChanged(uint8 amount);

    // Gas-related functions

    function deposit(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    ) external;

    function claim(uint64 _nonce) external;

    function withdraw(address _to) external payable;

    function setGasWithdrawalFee(uint256 _fee) external;

    function setGasWithdrawalMinAmount(uint256 _amount) external;

    function setGasWithdrawalMaxAmount(uint256 _amount) external;

    // should this be gas-unrelated, i.e., general?
    function setGasMaxNrDepositsPerDistribution(uint8 _maxNrDeposits) external;
}

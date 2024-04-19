// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgeManagementImpl.sol";
import "./BridgeStorage.sol";

interface IBridge {
    event Locked();
    event Unlocked();
    event Funded(uint256 amount);
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

    function deposit(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    ) external;

    function claim(uint64 _nonce) external;

    function withdraw(address _to) external payable;

    function lock() external;

    function unlock() external;

    function setGasWithdrawalFee(uint256 _fee) external;

    function setGasWithdrawalMinAmount(uint256 _amount) external;

    function setGasWithdrawalMaxAmount(uint256 _amount) external;

    function setGasMaxNrDepositsPerDistribution(uint8 _maxNrDeposits) external;
}

/**
 * When generating the bytecode for genesis script:
 * - set initial storage values in BridgeStorage.sol
 */
contract BridgeImpl is IBridge, BridgeStorage {
    receive() external payable onlyFunder {
        emit Funded(msg.value);
    }

    function deposit(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    ) external onlyRelayer unlocked {
        State memory state = _getGasBridgeDepositState();
        Config memory config = _getGasBridgeConfig();
        uint depositLength = _deposits.length;
        if (depositLength == 0) revert InvalidDepositsLength();
        if (depositLength > config.maxDepositsPerDistribution)
            revert InvalidDepositsLength();
        if (!BridgeLib._subsequentNonces(_deposits, state.nonce))
            revert InvalidNonceSequence();
        if (BridgeLib._computeNewTopRoot(state.root, _deposits) != _depositRoot)
            revert InvalidRoot();
        if (!management.verifyValidatorSignatures(_depositRoot, _signatures))
            revert InvalidValidatorSignatures();

        _setGasBridgeDepositState(
            State({
                nonce: _deposits[depositLength - 1].nonce,
                root: _depositRoot
            })
        );
        _executeTransfers(_deposits);
    }

    function _executeTransfers(
        BridgeLib.DepositData[] calldata _deposits
    ) private {
        // Once this is reached, execute the deposits
        for (uint i = 0; i < _deposits.length; i++) {
            BridgeLib.DepositData calldata depositEntry = _deposits[i];
            address to = depositEntry.to;
            if (BridgeLib._isContract(to)) {
                _addClaimableGas(depositEntry.nonce, depositEntry.amount, to);
                emit Claimable(depositEntry.nonce, depositEntry.amount, to);
            } else {
                uint256 sendValue = BridgeLib._addTenDecimals(
                    depositEntry.amount
                );
                // Todo: Verify that this call works as expected, i.e., the funds have not been sent if it returns false.
                (bool success, ) = to.call{value: sendValue}("");
                if (success) {
                    emit Deposit(depositEntry.nonce, depositEntry.amount, to);
                } else {
                    _addClaimableGas(
                        depositEntry.nonce,
                        depositEntry.amount,
                        to
                    );
                    emit Claimable(depositEntry.nonce, depositEntry.amount, to);
                }
            }
        }
    }

    // Anyone can execute a claim. The funds of a claimable will be sent to the defined address in the claimableTo mapping.
    function claim(uint64 _nonce) external unlocked {
        GasClaimable memory claimable = _getGasClaimable(_nonce);
        uint256 amount = claimable.amount;
        address to = claimable.to;
        if (amount == 0) revert NonexistentClaimable();
        if (to == address(0)) revert NonexistentClaimable();

        _deleteGasClaimable(_nonce);
        uint256 sendValue = BridgeLib._addTenDecimals(amount);
        (bool success, ) = to.call{value: sendValue}("");
        if (!success) revert TransferFailed();
        emit Claimed(_nonce, uint64(amount), to);
    }

    function withdraw(address _to) external payable unlocked {
        if (_to == address(0)) revert InvalidAddress();
        if ((msg.value % (10 ** 10)) != 0) revert InvalidAmount();
        Config memory config = _getGasBridgeConfig();
        State memory state = _getGasBridgeWithdrawalState();
        uint256 actualWithdrawalAmount = msg.value - config.fee;
        if (actualWithdrawalAmount < config.minAmount) revert InvalidAmount();
        if (actualWithdrawalAmount > config.maxAmount) revert InvalidAmount();

        uint64 amountForHashing = BridgeLib._removeTenDecimals(
            actualWithdrawalAmount
        );
        uint64 newNonce = state.nonce + 1;
        bytes32 withdrawalHash = BridgeLib._hashDepositOrWithdrawal(
            newNonce,
            amountForHashing,
            _to
        );
        bytes32 newRoot = BridgeLib._computeNewWithdrawalRoot(
            state.root,
            withdrawalHash
        );
        _setGasBridgeWithdrawalState(State({nonce: newNonce, root: newRoot}));
        emit Withdrawal(
            newNonce,
            amountForHashing,
            _to,
            msg.sender,
            withdrawalHash,
            newRoot
        );
    }

    // Contract Locking

    function lock() external onlySecurityGuard unlocked {
        _lock();
        emit Unlocked();
    }

    function unlock() external onlyGovernor {
        _unlock();
        emit Locked();
    }

    // Bridge Parameter Setters

    function setGasWithdrawalFee(uint256 _fee) external onlyGovernor {
        _setGasWithdrawalFee(_fee);
        emit WithdrawalFeeChanged(_fee);
    }

    function setGasWithdrawalMinAmount(uint256 _amount) external onlyGovernor {
        _setGasWithdrawalMinAmount(_amount);
        emit MinWithdrawalAmountChanged(_amount);
    }

    function setGasWithdrawalMaxAmount(uint256 _amount) external onlyGovernor {
        _setGasWithdrawalMaxAmount(_amount);
        emit MaxWithdrawalAmountChanged(_amount);
    }

    function setGasMaxNrDepositsPerDistribution(
        uint8 _maxNrDeposits
    ) external onlyGovernor {
        _setGasMaxNrDepositsPerDistribution(_maxNrDeposits);
        emit MaxDepositsPerDistributionChanged(_maxNrDeposits);
    }
}

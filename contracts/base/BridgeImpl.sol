// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../management/BridgeManagementImpl.sol";
import "./BridgeStorage.sol";
import "./IBridge.sol";
import "./IGasBridge.sol";
import "./ITokenBridge.sol";

/**
 * When generating the bytecode for genesis script:
 * - set initial storage values in BridgeStorage.sol
 */
contract BridgeImpl is IBridge, IGasBridge, ITokenBridge, BridgeStorage {
    receive() external payable onlyFunder {
        emit Funded(msg.value);
    }

    constructor(address _management) BridgeStorage(_management) {}

    function deposit(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    ) external onlyRelayer unlocked {
        BridgeStorageTypes.State memory state = _getGasBridgeDepositState();
        BridgeStorageTypes.GasConfig memory config = _getGasBridgeConfig();
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
            BridgeStorageTypes.State({
                nonce: _deposits[depositLength - 1].nonce,
                root: _depositRoot
            })
        );
        // Execution data interface
        _executeTransfers(_deposits);
    }

    function _executeTransfers(
        BridgeLib.DepositData[] calldata _deposits
    ) private {
        // Once this is reached, execute the deposits
        uint depositLength = _deposits.length;
        for (uint i = 0; i < depositLength; i++) {
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
    function claim(uint256 _nonce) external unlocked {
        BridgeStorageTypes.Claimable memory claimable = _getGasClaimable(
            _nonce
        );
        uint256 amount = claimable.amount;
        address to = claimable.to;
        if (amount == 0) revert NonexistentClaimable();
        if (to == address(0)) revert NonexistentClaimable();

        _deleteGasClaimable(_nonce);
        uint256 sendValue = BridgeLib._addTenDecimals(amount);
        (bool success, ) = to.call{value: sendValue}("");
        if (!success) revert TransferFailed();
        emit Claimed(_nonce, amount, to);
    }

    function withdraw(address _to) external payable unlocked {
        if (_to == address(0)) revert InvalidAddress();
        if ((msg.value % (10 ** 10)) != 0) revert InvalidAmount();
        BridgeStorageTypes.GasConfig memory config = _getGasBridgeConfig();
        BridgeStorageTypes.State memory state = _getGasBridgeWithdrawalState();
        uint256 actualWithdrawalAmount = msg.value - config.fee;
        if (actualWithdrawalAmount < config.minAmount) revert InvalidAmount();
        if (actualWithdrawalAmount > config.maxAmount) revert InvalidAmount();

        uint256 amountForHashing = BridgeLib._removeTenDecimals(
            actualWithdrawalAmount
        );
        uint256 newNonce = state.nonce + 1;
        bytes32 withdrawalHash = BridgeLib._hashDepositOrWithdrawal(
            newNonce,
            amountForHashing,
            _to
        );
        bytes32 newRoot = BridgeLib._computeNewRoot(state.root, withdrawalHash);
        _setGasBridgeWithdrawalState(
            BridgeStorageTypes.State({nonce: newNonce, root: newRoot})
        );
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

    // ITokenBridge Implementation

    /**
     * @notice Register a new token bridge.
     * @param identifier an identifier that is unique to the token bridge.
     * @param tokenType the type of token that is being registered.
     * @param tokenConfig the configuration of the token bridge.
     */
    function registerToken(
        uint256 identifier,
        BridgeStorageTypes.TokenType tokenType,
        BridgeStorageTypes.TokenConfig calldata tokenConfig
    ) external override {
        _registerToken(identifier, tokenType, tokenConfig);
        emit TokenRegister(identifier, tokenType, tokenConfig);
    }

    /**
     * @notice Unregister a token bridge.
     * @param identifier the identifier of the token bridge.
     */
    function unregisterToken(
        uint256 identifier
    ) external override onlyGovernor tokenLocked(identifier) {
        _unregisterToken(identifier);
        emit TokenUnregister(identifier);
    }

    /**
     * @notice Lock a token bridge. No deposits, withdrawals, or claims of a token bridge can be made while it is locked.
     * @param _identifier the identifier of the token bridge.
     */
    function lockToken(
        uint256 _identifier
    ) external override tokenUnlocked(_identifier) onlyGovernor {
        _lockToken(_identifier);
        emit TokenLock(_identifier);
    }

    /**
     * @notice Unlock a token bridge. Deposits, withdrawals, or claims of a token bridge can only be made while it is unlocked.
     * @param _identifier the identifier of the token bridge.
     */
    function unlockToken(
        uint256 _identifier
    ) external override tokenLocked(_identifier) onlyGovernor {
        _unlockToken(_identifier);
        emit TokenUnlock(_identifier);
    }

    function setTokenWithdrawalMinAmount(
        uint identifier,
        uint256 minAmount
    ) external override {
        // TODO: Implement
    }

    function setTokenWithdrawalMaxAmount(
        uint256 identifier,
        uint256 maxAmount
    ) external override {
        // TODO: Implement
    }

    function depositToken(
        uint256 identifier,
        BridgeLib.DepositData[] calldata deposits,
        bytes32 depositRoot,
        BridgeLib.Signature[] calldata signatures
    ) external override {
        // TODO: Implement
    }

    function withdrawToken(
        uint256 identifier,
        uint256 amount,
        address to
    ) external override {
        // TODO: Implement
    }

    function claimToken(uint256 identifier, uint256 nonce) external override {
        // TODO: Implement
    }
}

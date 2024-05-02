// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../management/BridgeManagementImpl.sol";
import "./BridgeStorage.sol";
import "./IBridge.sol";
import "./IGasBridge.sol";
import "./ITokenBridge.sol";
import "../interfaces/IERC20Capped.sol";

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
     * @param _id an identifier that is unique to the token bridge.
     * @param _tokenType the type of token that is being registered.
     * @param _tokenConfig the configuration of the token bridge.
     */
    function registerToken(
        uint256 _id,
        BridgeStorageTypes.TokenType _tokenType,
        BridgeStorageTypes.TokenConfig calldata _tokenConfig
    ) external override {
        _registerToken(_id, _tokenType, _tokenConfig);
        emit TokenRegister(_id, _tokenType, _tokenConfig);
    }

    /**
     * @notice Unregister a token bridge.
     * @param _id the identifier of the token bridge.
     */
    function unregisterToken(
        uint256 _id
    ) external override onlyGovernor tokenLocked(_id) {
        _unregisterToken(_id);
        emit TokenUnregister(_id);
    }

    /**
     * @notice Lock a token bridge. No deposits, withdrawals, or claims of a token bridge can be made while it is locked.
     * @param _id the identifier of the token bridge.
     */
    function lockToken(
        uint256 _id
    ) external override tokenUnlocked(_id) onlyGovernor {
        _lockToken(_id);
        emit TokenLock(_id);
    }

    /**
     * @notice Unlock a token bridge. Deposits, withdrawals, or claims of a token bridge can only be made while it is unlocked.
     * @param _id the identifier of the token bridge.
     */
    function unlockToken(
        uint256 _id
    ) external override tokenLocked(_id) onlyGovernor {
        _unlockToken(_id);
        emit TokenUnlock(_id);
    }

    function setTokenWithdrawalMinAmount(
        uint256 _id,
        uint256 _minAmount
    ) external override onlyGovernor {
        _setTokenMinWithdrawalAmount(_id, _minAmount);
        emit TokenMinWithdrawalAmountChanged(_id, _minAmount);
    }

    function setTokenWithdrawalMaxAmount(
        uint256 _id,
        uint256 _maxAmount
    ) external override onlyGovernor {
        _setTokenMaxWithdrawalAmount(_id, _maxAmount);
        emit TokenMaxWithdrawalAmountChanged(_id, _maxAmount);
    }

    function depositToken(
        uint256 _id,
        BridgeLib.DepositData[] calldata _deposits,
        bytes32 _tokenDepositRoot,
        BridgeLib.Signature[] calldata _signatures
    ) external override tokenUnlocked(_id) {
        BridgeStorageTypes.State memory depositState = _getTokenDepositState(
            _id
        );
        BridgeStorageTypes.TokenType tokenType = _getTokenType(_id);
        BridgeStorageTypes.TokenTypeConfig
            memory tokenTypeConfig = _getTokenTypeConfig(tokenType);

        // Check parameter validity
        uint depositLength = _deposits.length;
        if (depositLength == 0) revert InvalidDepositsLength();
        if (depositLength > tokenTypeConfig.maxDepositsPerDistribution)
            revert InvalidDepositsLength();
        // Check if provided deposit data's nonces are subsequent to the current nonce and each other.
        if (!BridgeLib._subsequentNonces(_deposits, depositState.nonce))
            revert InvalidNonceSequence();
        // Validate that the provided token deposit root is equal to the new computed root based on the provided deposits.
        if (
            TokenBridgeLib._computeNewTopRootToken(
                depositState.root,
                _id,
                _deposits
            ) != _tokenDepositRoot
        ) revert InvalidRoot();
        // Verify that the provided signatures are valid given the provided deposit root and the current validators.
        if (
            !management.verifyValidatorSignatures(
                _tokenDepositRoot,
                _signatures
            )
        ) revert InvalidValidatorSignatures();

        // Update the token's deposit state
        _setTokenDepositState(
            _id,
            BridgeStorageTypes.State({
                nonce: _deposits[depositLength - 1].nonce,
                root: _tokenDepositRoot
            })
        );

        // Execute the token distribution
        _executeTokenDistribution(_id, tokenType, _deposits);
    }

    function _executeTokenDistribution(
        uint256 _id,
        BridgeStorageTypes.TokenType _tokenType,
        BridgeLib.DepositData[] calldata _deposits
    ) private {
        uint depositLength = _deposits.length;
        address contractAddress = _getTokenConfig(_id).contractAddress;
        // Execute the token distribution for each deposit entry
        for (uint i = 0; i < depositLength; i++) {
            BridgeLib.DepositData calldata depositEntry = _deposits[i];
            address to = depositEntry.to;
            bool success = false;
            if (_tokenType == BridgeStorageTypes.TokenType.ERC20Capped) {
                // Execute the token distribution for ERC20Capped tokens
                IERC20Capped tokenContract = IERC20Capped(contractAddress);
                success = _executeERC20CappedTransfer(
                    tokenContract,
                    depositEntry.amount,
                    to
                );
            }
            // For future token types add an else if block here
            else {
                assert(false);
            }
            _emitTransferEventOrAddNewTokenClaimable(
                success,
                _id,
                depositEntry.nonce,
                depositEntry.amount,
                to
            );
        }
    }

    function claimToken(uint256 _id, uint256 _nonce) external override {
        BridgeStorageTypes.Claimable memory claimable = _getTokenClaimable(
            _id,
            _nonce
        );
        // Check if the claimable exists.
        if (claimable.to == address(0)) revert NonexistentClaimable();
        _deleteTokenClaimable(_id, _nonce);
        BridgeStorageTypes.TokenConfig memory config = _getTokenConfig(_id);
        address contractAddress = config.contractAddress;
        if (_getTokenType(_id) == BridgeStorageTypes.TokenType.ERC20Capped) {
            IERC20Capped tokenContract = IERC20Capped(contractAddress);
            _executeERC20CappedTransfer(
                tokenContract,
                claimable.amount,
                claimable.to
            );
        } else {
            assert(false);
        }
    }

    function _emitTransferEventOrAddNewTokenClaimable(
        bool _success,
        uint256 _id,
        uint256 _nonce,
        uint256 _amount,
        address _to
    ) private {
        if (_success) {
            emit TokenDeposit(_id, _nonce, _amount, _to);
        } else {
            _addTokenClaimable(_id, _nonce, _amount, _to);
            emit TokenClaimable(_id, _nonce, _amount, _to);
        }
    }

    function _executeERC20CappedTransfer(
        IERC20Capped _tokenContract,
        uint256 _amount,
        address _to
    ) private returns (bool) {
        return _tokenContract.transfer(_to, _amount);
    }

    /**
     * @notice Withdraw tokens to Neo N3.
     * @dev This function must be called by the contract that is registered and thus is responsible for bridging the tokens. This can but need not be the token contract itself.
     * @param _amount the amount of tokens to withdraw.
     * @param _to the address to which the tokens should be sent.
     */
    function withdrawToken(uint256 _amount, address _to) external override {
        // Get the token identifier based on the message sender.
        uint256 id = _getTokenId(msg.sender);
        BridgeStorageTypes.TokenConfig memory config = _getTokenConfig(id);
        assert(config.contractAddress == msg.sender);
        if (_amount < config.minAmount) revert InvalidAmount();
        if (_amount > config.maxAmount) revert InvalidAmount();

        // Compute the new root and update the token withdrawal state.
        BridgeStorageTypes.State memory state = _getTokenWithdrawalState(id);
        uint256 newNonce = state.nonce + 1;
        bytes32 withdrawalHash = TokenBridgeLib._hashTokenBridgeOp(
            id,
            newNonce,
            _amount,
            _to
        );
        bytes32 newRoot = BridgeLib._computeNewRoot(state.root, withdrawalHash);
        _setTokenWithdrawalState(
            id,
            BridgeStorageTypes.State({nonce: newNonce, root: newRoot})
        );
        emit TokenWithdrawal(id, state.nonce, _amount, _to);
    }
}

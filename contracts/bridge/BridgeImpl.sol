// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./BridgeStorage.sol";
import "../interfaces/IBridge.sol";
import "../interfaces/IGasBridge.sol";
import "../interfaces/ITokenBridge.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BridgeImpl is BridgeStorage, IBridge, IGasBridge, ITokenBridge {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable onlyFunder {
        emit Fund(msg.value);
    }

    // Contract Pausing

    /**
     * @notice Pauses the bridge. No deposits or withdrawals can be made while the bridge is paused. This feature is useful to halt any interaction with the contract besides governor actions, such as updating parameters or registering new token bridges, or contract updates.
     */
    function pauseBridge()
        external
        onlyGovernorOrSecurityGuard
        whenBridgeNotPaused
    {
        _pauseBridge();
        emit BridgePause();
    }

    function unpauseBridge() external onlyGovernor whenBridgePaused {
        _unpauseBridge();
        emit BridgeUnpause();
    }

    /**
     * @notice Pauses withdrawals. No withdrawals can be made while withdrawals are paused. This feature is useful in the case of a planned contract update that involves a change in the computation of the hash chain roots. By pausing the deposits, there will be no new deposits and the relayer can be given time to catch-up with relaying everything that is currently in progress (i.e., the relayer can still use the withdrawal functions) before the bridge is completely paused (i.e., with {@link #pauseBridge()}) and the contract is updated.
     */
    function pauseWithdrawals() external onlyGovernor whenWithdrawalsNotPaused {
        _pauseWithdrawals();
        emit WithdrawalPause();
    }

    function unpauseWithdrawals() external onlyGovernor whenWithdrawalsPaused {
        _unpauseWithdrawals();
        emit WithdrawalUnpause();
    }

    // IGasBridge Implementation

    function pauseGasBridge()
        external
        override
        onlyGovernorOrSecurityGuard
        whenGasBridgeNotPaused
    {
        _pauseGasBridge();
        emit GasBridgePause();
    }

    function unpauseGasBridge()
        external
        override
        onlyGovernor
        whenGasBridgePaused
    {
        _unpauseGasBridge();
        emit GasBridgeUnpause();
    }

    /**
     * @notice Distributes Gas that has been locked on Neo N3.
     * @dev The depositGas function is used to distribute Gas that has been locked on Neo N3.
     *      The deposits data need to be provided ordered based on their nonces.
     *      Before the deposits are distributed, the following steps are executed:
     *      - Check if the provided deposits are subsequent to the current nonce in storage and each other.
     *      - Check if the computed root based on the provided deposits matches the provided root.
     *      - Check if the provided signatures are valid given the provided root and the current validators.
     *      Once these checks are passed, the storage state is updated with the new nonce and root, and the deposits are distributed.
     * @param _depositRoot the new deposit root.
     * @param _signatures the signatures of the validators. The signatures need to be ordered based on the order they have been stored in storage.
     * @param _deposits the deposit data.
     */
    function depositGas(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    )
        external
        onlyRelayer
        whenBridgeNotPaused
        whenGasBridgeNotPaused
        nonReentrant
    {
        StorageTypes.State memory state = _getGasBridgeDepositState();
        StorageTypes.GasConfig memory config = _getGasBridgeConfig();
        uint256 depositLength = _deposits.length;
        if (depositLength == 0) revert InvalidDepositsLength();
        if (depositLength > config.maxDeposits) revert InvalidDepositsLength();
        if (!BridgeLib._subsequentNonces(_deposits, state.nonce))
            revert InvalidNonceSequence();
        if (
            GasBridgeLib._computeNewTopRoot(state.root, _deposits) !=
            _depositRoot
        ) revert InvalidRoot();
        if (!management.verifyValidatorSignatures(_depositRoot, _signatures))
            revert InvalidValidatorSignatures();

        _setGasBridgeDepositState(
            StorageTypes.State({
                nonce: _deposits[depositLength - 1].nonce,
                root: _depositRoot
            })
        );
        emit GasDepositRootUpdate(
            _deposits[depositLength - 1].nonce,
            _depositRoot
        );

        // Execution data interface
        _executeGasTransfers(_deposits);
    }

    function _executeGasTransfers(
        BridgeLib.DepositData[] calldata _deposits
    ) private {
        uint256 depositLength = _deposits.length;
        for (uint256 i = 0; i < depositLength; i++) {
            BridgeLib.DepositData calldata depositEntry = _deposits[i];
            address to = depositEntry.to;
            if (BridgeLib._isContract(to)) {
                _addClaimableGas(depositEntry.nonce, to, depositEntry.amount);
                emit GasClaimable(depositEntry.nonce, to, depositEntry.amount);
            } else {
                uint256 sendValue = GasBridgeLib._addTenDecimals(
                    depositEntry.amount
                );
                (bool success, ) = to.call{value: sendValue}("");
                if (success) {
                    emit GasDeposit(
                        depositEntry.nonce,
                        to,
                        depositEntry.amount
                    );
                } else {
                    _addClaimableGas(
                        depositEntry.nonce,
                        to,
                        depositEntry.amount
                    );
                    emit GasClaimable(
                        depositEntry.nonce,
                        to,
                        depositEntry.amount
                    );
                }
            }
        }
    }

    /**
     * @notice Claim Gas that has been deposited to Neo X and was not distributed. Anyone can execute a claim. The funds of a claimable will be sent to the defined address in storage regardless of who claims it.
     * @param _nonce the nonce of the claimable.
     */
    function claimGas(
        uint256 _nonce
    ) external whenBridgeNotPaused whenGasBridgeNotPaused nonReentrant {
        StorageTypes.Claimable memory claimable = _getGasClaimable(_nonce);
        uint256 amount = claimable.amount;
        address to = claimable.to;
        if (amount == 0) revert NonexistentClaimable();
        if (to == address(0)) revert NonexistentClaimable();

        _deleteGasClaimable(_nonce);
        uint256 sendValue = GasBridgeLib._addTenDecimals(amount);
        (bool success, ) = to.call{value: sendValue}("");
        if (!success) revert TransferFailed();
        emit GasClaim(_nonce, to, amount);
    }

    /**
     * @notice Withdraw Gas to provided address on Neo N3. The provided amount of Gas after the fee deduction must have a precision of maximal 8 decimal points matching the 8 decimals of the GAS token on Neo N3.
     * @dev When invoking this function provide the amount of Gas to withdraw to Neo N3 as msg.value.
     * @param _to the address to which the Gas should be sent on Neo N3.
     * @param _maxFee the maximum fee that the sender is willing to pay for the withdrawal. If the actual fee is higher than this value, the withdrawal is aborted.
     */
    function withdrawGas(
        address _to,
        uint256 _maxFee
    )
        external
        payable
        whenBridgeNotPaused
        whenWithdrawalsNotPaused
        whenGasBridgeNotPaused
    {
        if (_to == address(0)) revert InvalidAddress();
        StorageTypes.GasConfig memory config = _getGasBridgeConfig();
        uint256 fee = config.fee;
        if (msg.value < fee) revert InsufficientFee(fee, msg.value); // Prevents underflow and provides clear feedback
        // Revert if the actual fee is higher than the provided max fee.
        if (fee > _maxFee) revert MaxFeeExceeded(_maxFee, fee);
        _addUnclaimedRewards(fee);

        uint256 withdrawalAmount = msg.value - fee;
        // Revert if the withdrawal amount is not a multiple of 1e10, matching the 8 decimals of Gas on Neo N3.
        if ((withdrawalAmount % 1e10) != 0) revert InvalidAmount();
        // Revert if the withdrawal amount is outside the allowed range.
        if (withdrawalAmount < config.minAmount)
            revert AmountBelowMinAmount(config.minAmount, withdrawalAmount);
        if (withdrawalAmount > config.maxAmount)
            revert AmountExceedsMaxAmount(config.maxAmount, withdrawalAmount);

        // The actual withdrawal amount is the sent value minus the fee.
        uint256 amountForHashing = GasBridgeLib._removeTenDecimals(
            withdrawalAmount
        );

        StorageTypes.State memory state = _getGasBridgeWithdrawalState();
        uint256 newNonce = state.nonce + 1;
        bytes32 withdrawalHash = GasBridgeLib._hashGasBrideOp(
            newNonce,
            _to,
            amountForHashing
        );
        bytes32 newRoot = BridgeLib._computeNewRoot(state.root, withdrawalHash);
        _setGasBridgeWithdrawalState(
            StorageTypes.State({nonce: newNonce, root: newRoot})
        );
        emit GasWithdrawal(
            newNonce,
            _to,
            amountForHashing,
            msg.sender,
            withdrawalHash,
            newRoot
        );
    }

    function setGasWithdrawalFee(uint256 _fee) external onlyGovernor {
        _setGasWithdrawalFee(_fee);
        emit GasWithdrawalFeeChange(_fee);
    }

    function setMinGasWithdrawalAmount(uint256 _amount) external onlyGovernor {
        _setGasWithdrawalMinAmount(_amount);
        emit MinGasWithdrawalChange(_amount);
    }

    function setMaxGasWithdrawalAmount(uint256 _amount) external onlyGovernor {
        _setGasWithdrawalMaxAmount(_amount);
        emit MaxGasWithdrawalChange(_amount);
    }

    function setMaxGasDeposits(uint256 _maxNrDeposits) external onlyGovernor {
        _setMaxGasDeposits(_maxNrDeposits);
        emit MaxGasDepositsChange(_maxNrDeposits);
    }

    // ITokenBridge Implementation

    /**
     * @notice Register a new token bridge.
     * @param _neoXToken the address of the token on the Neo X network.
     * @param _tokenConfig the configuration of the token bridge. Make sure the provided fee, minAmount and maxDeposits is not zero and the maxAmount is greater than the minAmount.
     */
    function registerToken(
        address _neoXToken,
        StorageTypes.TokenConfig calldata _tokenConfig
    ) external override onlyGovernor {
        if (_neoXToken == address(0)) revert InvalidTokenAddress();
        if (!TokenBridgeLib._isValidConfig(_tokenConfig))
            revert InvalidTokenConfig();
        _registerToken(_neoXToken, _tokenConfig);
        emit TokenRegister(_neoXToken, _tokenConfig);
    }

    /**
     * @notice Check if a token is registered on the bridge.
     * @param _neoXToken the address of the token on the Neo X network.
     */
    function isRegisteredToken(
        address _neoXToken
    ) external view override returns (bool) {
        return _isRegisteredToken(_neoXToken);
    }

    /**
     * @notice Pause a token bridge. No deposits, withdrawals, or claims of a token bridge can be made while it is locked.
     * @param _neoXToken the address of the token on the Neo X network.
     */
    function pauseTokenBridge(
        address _neoXToken
    )
        external
        override
        onlyGovernorOrSecurityGuard
        onlyIfTokenRegistered(_neoXToken)
        whenTokenBridgeNotPaused(_neoXToken)
    {
        _pauseToken(_neoXToken);
        emit TokenBridgePause(_neoXToken, _getNeoN3Token(_neoXToken));
    }

    /**
     * @notice Unpause a token bridge. Deposits, withdrawals, or claims of a token bridge can only be made while it is unlocked.
     * @param _neoXToken the address of the token on the Neo X network.
     */
    function unpauseTokenBridge(
        address _neoXToken
    )
        external
        override
        onlyGovernor
        onlyIfTokenRegistered(_neoXToken)
        whenTokenBridgePaused(_neoXToken)
    {
        _unpauseToken(_neoXToken);
        emit TokenBridgeUnpause(_neoXToken, _getNeoN3Token(_neoXToken));
    }

    /**
     * @notice Distributes the provided Token that has been locked on Neo N3.
     * @dev The depositToken function is used to distribute tokens that have been locked on Neo N3.
     *      The deposits data need to be provided ordered based on their nonces.
     *      Before the deposits are distributed, the following steps are executed:
     *      - Check if the provided deposits are subsequent to the current nonce in storage and each other.
     *      - Check if the computed root based on the provided deposits matches the provided root.
     *      - Check if the provided signatures are valid given the provided root and the current validators.
     *      Once these checks are passed, the storage state is updated with the new nonce and root, and the deposits are distributed.
     * @param _neoXToken the address of the token on the Neo X network.
     * @param _tokenDepositRoot the new deposit root. The root must be the root that resulted from the last provided deposit.
     * @param _signatures the signatures of the validators. The signatures need to be ordered based on the order they have been stored in storage.
     * @param _deposits the deposit data. Each deposit's nonce, recipient address and the amount.
     */
    function depositToken(
        address _neoXToken,
        bytes32 _tokenDepositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    )
        external
        override
        onlyRelayer
        whenBridgeNotPaused
        onlyIfTokenRegistered(_neoXToken)
        whenTokenBridgeNotPaused(_neoXToken)
        nonReentrant
    {
        StorageTypes.State memory depositState = _getTokenDepositState(
            _neoXToken
        );
        StorageTypes.TokenConfig memory config = _getTokenConfig(_neoXToken);

        // Check parameter validity
        uint256 depositLength = _deposits.length;
        if (depositLength == 0) revert InvalidDepositsLength();
        if (depositLength > config.maxDeposits) revert InvalidDepositsLength();
        // Check if provided deposit data's nonces are subsequent to the current nonce and each other.
        if (!BridgeLib._subsequentNonces(_deposits, depositState.nonce))
            revert InvalidNonceSequence();
        // Validate that the provided token deposit root is equal to the new computed root based on the provided deposits.
        if (
            TokenBridgeLib._computeNewTopRoot(
                depositState.root,
                _getNeoN3Token(_neoXToken),
                _neoXToken,
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
            _neoXToken,
            StorageTypes.State({
                nonce: _deposits[depositLength - 1].nonce,
                root: _tokenDepositRoot
            })
        );
        emit TokenDepositRootUpdate(
            _neoXToken,
            config.neoN3Token,
            _deposits[depositLength - 1].nonce,
            _tokenDepositRoot
        );

        // Execute the token distribution
        _executeTokenDistribution(
            _neoXToken,
            config.decimalScalingFactor,
            _deposits
        );
    }

    function _executeTokenDistribution(
        address _neoXToken,
        uint256 _decimalScalingFactor,
        BridgeLib.DepositData[] calldata _deposits
    ) private {
        uint256 depositLength = _deposits.length;
        // Execute the token distribution for each deposit entry
        for (uint256 i = 0; i < depositLength; i++) {
            BridgeLib.DepositData calldata depositEntry = _deposits[i];
            address to = depositEntry.to;
            uint256 transferAmount = depositEntry.amount;
            if (_decimalScalingFactor > 0) {
                transferAmount *= (10 ** _decimalScalingFactor);
            }
            bool success = TokenBridgeLib._safeERC20Transfer(
                IERC20(_neoXToken),
                to,
                transferAmount
            );
            _emitTransferEventOrAddNewTokenClaimable(
                success,
                _neoXToken,
                depositEntry.nonce,
                to,
                transferAmount
            );
        }
    }

    /**
     * @notice Claim tokens that have been deposited to Neo X and were not distributed. Anyone can execute a claim. The funds of a claimable will be sent to the defined address in storage regardless of who claims it.
     * @param _neoXToken the address of the token on the Neo X network.
     * @param _nonce the nonce of the claimable.
     */
    function claimToken(
        address _neoXToken,
        uint256 _nonce
    )
        external
        override
        nonReentrant
        whenBridgeNotPaused
        onlyIfTokenRegistered(_neoXToken)
        whenTokenBridgeNotPaused(_neoXToken)
    {
        StorageTypes.Claimable memory claimable = _getTokenClaimable(
            _neoXToken,
            _nonce
        );
        // Check if the claimable exists.
        address to = claimable.to;
        if (to == address(0)) revert NonexistentClaimable();
        _deleteTokenClaimable(_neoXToken, _nonce);
        // Note: For NEO tokens, the transfer value has already been extended with 18 decimals in the deposit function.
        // If no value is returned, non-reverting calls are assumed to be successful.
        SafeERC20.safeTransfer(IERC20(_neoXToken), to, claimable.amount);
    }

    function _emitTransferEventOrAddNewTokenClaimable(
        bool _success,
        address _neoXToken,
        uint256 _nonce,
        address _to,
        uint256 _amount
    ) private {
        if (_success) {
            emit TokenDeposit(_neoXToken, _nonce, _to, _amount);
        } else {
            _addTokenClaimable(_neoXToken, _nonce, _to, _amount);
            emit TokenClaimable(_neoXToken, _nonce, _to, _amount);
        }
    }

    /**
     * @notice Withdraw tokens to Neo N3. Requires that the sender has approved the provided amount to the bridge contract. The fee required for withdrawing that token can be fetched from its config (i.e., tokenBridges[_neoXToken].config.fee). It needs to be payed to this function (i.e., as msg.value).
     * @dev This function transfers the provided amount of the provided token from the msg.sender to this contract. It requires that the msg.sender has previously approved at least the provided amount to this contract. Further, it computes the new root and updates the token withdrawal state. Note, that potential fee deductions by a token contract need to be considered when setting the _amount parameter, i.e., the allowed range for amount values is checked against the actual received amount of tokens.
     * @param _neoXToken the address of the token on the Neo X network.
     * @param _to the address to which the tokens should be sent on Neo N3.
     * @param _amount the amount of tokens to transfer to the bridge contract in order to withdraw them to Neo N3.
     */
    function withdrawToken(
        address _neoXToken,
        address _to,
        uint256 _amount
    )
        external
        payable
        override
        nonReentrant
        whenBridgeNotPaused
        whenWithdrawalsNotPaused
        onlyIfTokenRegistered(_neoXToken)
        whenTokenBridgeNotPaused(_neoXToken)
    {
        if (_to == address(0)) revert InvalidAddress();
        StorageTypes.TokenConfig memory config = _getTokenConfig(_neoXToken);
        address from = msg.sender;
        _processTokenWithdrawalFee(from, msg.value, config.fee);

        uint256 receivedAmount = _transferERC20TokenToBridge(
            _neoXToken,
            from,
            _amount
        );
        // Check that the received amount is in the allowed range.
        if (receivedAmount < config.minAmount)
            revert AmountBelowMinAmount(config.minAmount, receivedAmount);
        if (receivedAmount > config.maxAmount)
            revert AmountExceedsMaxAmount(config.maxAmount, receivedAmount);

        // Compute the new root and update the token withdrawal state.
        StorageTypes.State memory state = _getTokenWithdrawalState(_neoXToken);
        uint256 newNonce = state.nonce + 1;

        if (config.decimalScalingFactor > 0) {
            uint256 scalingFactor = 10 ** config.decimalScalingFactor;
            if (receivedAmount % scalingFactor != 0) {
                revert InvalidAmount();
            }
            receivedAmount /= scalingFactor;
        }

        bytes32 withdrawalHash = TokenBridgeLib._hashTokenBridgeOp(
            config.neoN3Token,
            _neoXToken,
            newNonce,
            _to,
            receivedAmount
        );
        bytes32 newRoot = BridgeLib._computeNewRoot(state.root, withdrawalHash);
        _setTokenWithdrawalState(
            _neoXToken,
            StorageTypes.State({nonce: newNonce, root: newRoot})
        );
        emit TokenWithdrawal(
            _neoXToken,
            config.neoN3Token,
            newNonce,
            _to,
            receivedAmount,
            from,
            withdrawalHash,
            newRoot
        );
    }

    /**
     * @dev Checks the provided value against the required fee. If the provided value exceeds the required fee, the
     * excess amount is refunded if the sender is an EOA. Otherwise, if the sender is a contract, it is reverted.
     * @param _from the sender.
     * @param _msgValue the value sent with the transaction.
     * @param _fee the required fee.
     */
    function _processTokenWithdrawalFee(
        address _from,
        uint256 _msgValue,
        uint256 _fee
    ) private {
        // Revert if the provided value is lower than the required fee.
        if (_msgValue < _fee) revert InsufficientFee(_fee, _msgValue);
        // Refund the sender (only EOAs) if the provided value is higher than the required fee.
        if (_msgValue > _fee) {
            // Revert if the sender is a contract.
            if (BridgeLib._isContract(_from)) {
                revert ExactFeeRequired(_fee, _msgValue);
            }
            (bool success, ) = payable(_from).call{value: _msgValue - _fee}("");
            if (!success) revert TransferFailed();
        }
        _addUnclaimedRewards(_fee);
    }

    function _transferERC20TokenToBridge(
        address _neoXToken,
        address _from,
        uint256 _amount
    ) private returns (uint256 actualReceivedAmount) {
        IERC20 erc20Token = IERC20(_neoXToken);
        uint256 bridgeBalanceBefore = erc20Token.balanceOf(address(this));
        SafeERC20.safeTransferFrom(erc20Token, _from, address(this), _amount);

        // Compare the balance before and after the transfer to get the actual received amount. This is necessary if the token contract were to deduct a fee in transfers.
        uint256 bridgeBalanceAfter = erc20Token.balanceOf(address(this));
        // Revert if there is an underflow.
        if (bridgeBalanceAfter < bridgeBalanceBefore) revert InvalidTransfer();
        uint256 receivedAmount = bridgeBalanceAfter - bridgeBalanceBefore;
        return receivedAmount;
    }

    function setTokenWithdrawalFee(
        address[] calldata _neoXTokens,
        uint256[] calldata _fees
    ) external override onlyGovernor {
        uint256 nrTokens = _neoXTokens.length;
        if (nrTokens != _fees.length) revert LengthMismatch();
        for (uint256 i = 0; i < nrTokens; i++) {
            uint256 fee = _fees[i];
            _setTokenWithdrawalFee(_neoXTokens[i], fee);
            emit TokenWithdrawalFeeChange(_neoXTokens[i], fee);
        }
    }

    function setMinTokenWithdrawalAmount(
        address[] calldata _neoXTokens,
        uint256[] calldata _minAmounts
    ) external override onlyGovernor {
        uint256 nrTokens = _neoXTokens.length;
        if (nrTokens != _minAmounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < nrTokens; i++) {
            uint256 minAmount = _minAmounts[i];
            _setTokenMinWithdrawalAmount(_neoXTokens[i], minAmount);
            emit MinTokenWithdrawalAmountChange(_neoXTokens[i], minAmount);
        }
    }

    function setMaxTokenWithdrawalAmount(
        address[] calldata _neoXTokens,
        uint256[] calldata _maxAmounts
    ) external override onlyGovernor {
        uint256 nrTokens = _neoXTokens.length;
        if (nrTokens != _maxAmounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < nrTokens; i++) {
            uint256 maxAmount = _maxAmounts[i];
            _setTokenMaxWithdrawalAmount(_neoXTokens[i], maxAmount);
            emit MaxTokenWithdrawalAmountChange(_neoXTokens[i], maxAmount);
        }
    }

    function setMaxTokenDeposits(
        address[] calldata _neoXTokens,
        uint256[] calldata _maxDeposits
    ) external override onlyGovernor {
        uint256 nrTokens = _neoXTokens.length;
        if (nrTokens != _maxDeposits.length) revert LengthMismatch();
        for (uint256 i = 0; i < nrTokens; i++) {
            uint256 maxDeposits = _maxDeposits[i];
            _setMaxTokenDeposits(_neoXTokens[i], maxDeposits);
            emit MaxTokenDepositsChange(_neoXTokens[i], maxDeposits);
        }
    }
}

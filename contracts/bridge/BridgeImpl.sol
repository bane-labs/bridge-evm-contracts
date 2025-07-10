// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../interfaces/IBridge.sol";
import "../interfaces/INativeBridge.sol";
import "../interfaces/ITokenBridge.sol";
import "../interfaces/IMessageBridge.sol";
import "../library/StorageTypes.sol";
import "../library/BridgeLib.sol";
import "../library/NativeBridgeLib.sol";
import "../library/TokenBridgeLib.sol";
import "../library/MessageBridgeLib.sol";
import "./BridgeStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BridgeImpl is BridgeStorage, IBridge, INativeBridge, ITokenBridge, IMessageBridge {
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
    function pauseBridge() external onlyGovernorOrSecurityGuard whenBridgeNotPaused {
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

    // INativeBridge Implementation

    function nativeBridgeIsSet() external view returns (bool) {
        return _nativeBridgeIsSet();
    }

    function setNativeBridge(
        uint256 _fee,
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _maxDeposits,
        uint256 _decimalsHere,
        uint256 _decimalsOnN3
    )
        external
        onlyGovernor
        onlyIfNativeBridgeNotSet
    {
        _setNativeBridge(_fee, _minAmount, _maxAmount, _maxDeposits, _decimalsHere, _decimalsOnN3);
    }

    function pauseNativeBridge()
        external
        override
        onlyGovernorOrSecurityGuard
        onlyIfNativeBridgeSet
        whenNativeBridgeNotPaused
    {
        _pauseNativeBridge();
        emit NativeBridgePause();
    }

    function unpauseNativeBridge() external override onlyGovernor onlyIfNativeBridgeSet whenNativeBridgePaused {
        _unpauseNativeBridge();
        emit NativeBridgeUnpause();
    }

    /**
     * @notice Distributes native coins that have been locked on Neo N3.
     * @dev The depositNative function is used to distribute native coins that have been locked on Neo N3.
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
    function depositNative(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    )
        external
        onlyRelayer
        whenBridgeNotPaused
        onlyIfNativeBridgeSet
        whenNativeBridgeNotPaused
        nonReentrant
    {
        StorageTypes.State memory state = _getNativeBridgeDepositState();
        StorageTypes.NativeConfig memory config = _getNativeBridgeConfig();
        uint256 depositLength = _deposits.length;
        if (depositLength == 0) revert InvalidDepositsLength();
        if (depositLength > config.maxDeposits) revert InvalidDepositsLength();
        if (!BridgeLib._subsequentNonces(_deposits, state.nonce)) revert InvalidNonceSequence();
        if (NativeBridgeLib._computeNewTopRoot(state.root, _deposits) != _depositRoot) revert InvalidRoot();
        if (!management.verifyValidatorSignatures(_depositRoot, _signatures)) revert InvalidValidatorSignatures();

        _setNativeBridgeDepositState(
            StorageTypes.State({nonce: _deposits[depositLength - 1].nonce, root: _depositRoot})
        );
        emit NativeDepositRootUpdate(_deposits[depositLength - 1].nonce, _depositRoot);

        // Execution data interface
        _executeNativeTransfers(_deposits, config.decimalScalingFactor);
    }

    function _executeNativeTransfers(
        BridgeLib.DepositData[] calldata _deposits,
        uint256 _decimalScalingFactor
    )
        private
    {
        uint256 depositLength = _deposits.length;
        for (uint256 i = 0; i < depositLength; i++) {
            BridgeLib.DepositData calldata depositEntry = _deposits[i];
            address to = depositEntry.to;
            if (BridgeLib._isContract(to)) {
                _addClaimableNative(depositEntry.nonce, to, depositEntry.amount);
                emit NativeClaimable(depositEntry.nonce, to, depositEntry.amount);
            } else {
                uint256 sendValue = depositEntry.amount * (10 ** _decimalScalingFactor);
                (bool success,) = to.call{value: sendValue}("");
                if (success) {
                    emit NativeDeposit(depositEntry.nonce, to, depositEntry.amount);
                } else {
                    _addClaimableNative(depositEntry.nonce, to, depositEntry.amount);
                    emit NativeClaimable(depositEntry.nonce, to, depositEntry.amount);
                }
            }
        }
    }

    /**
     * @notice Claim native coins that have been deposited to this chain and was not distributed. Anyone can execute a claim. The funds of a claimable will be sent to the defined address in storage regardless of who claims it.
     * @param _nonce the nonce of the claimable.
     */
    function claimNative(uint256 _nonce)
        external
        whenBridgeNotPaused
        onlyIfNativeBridgeSet
        whenNativeBridgeNotPaused
        nonReentrant
    {
        StorageTypes.Claimable memory claimable = _getNativeClaimable(_nonce);
        uint256 amount = claimable.amount;
        address to = claimable.to;
        if (amount == 0) revert NonexistentClaimable();
        if (to == address(0)) revert NonexistentClaimable();

        _deleteNativeClaimable(_nonce);
        uint256 sendValue = amount * (10 ** _getNativeBridgeConfig().decimalScalingFactor);
        (bool success,) = to.call{value: sendValue}("");
        if (!success) revert TransferFailed();
        emit NativeClaim(_nonce, to, amount);
    }

    // Todo (mialbu): Add decimal to NativeConfig
    /**
     * @notice Withdraw native coins to the provided address on Neo N3. The provided amount of native coins after the fee deduction must have a precision of maximal 8 decimal points matching the 8 decimals of the GAS token on Neo N3.
     * @dev When invoking this function provide the amount of native coins to withdraw to Neo N3 as msg.value.
     * @param _to the address to which the native coin's representative should be sent on Neo N3.
     * @param _maxFee the maximum fee that the sender is willing to pay for the withdrawal. If the actual fee is higher than this value, the withdrawal is aborted.
     */
    function withdrawNative(
        address _to,
        uint256 _maxFee
    )
        external
        payable
        whenBridgeNotPaused
        whenWithdrawalsNotPaused
        onlyIfNativeBridgeSet
        whenNativeBridgeNotPaused
    {
        if (_to == address(0)) revert InvalidAddress();
        StorageTypes.NativeConfig memory config = _getNativeBridgeConfig();
        uint256 fee = config.fee;
        if (msg.value < fee) revert InsufficientFee(fee, msg.value); // Prevents underflow and provides clear feedback
        // Revert if the actual fee is higher than the provided max fee.
        if (fee > _maxFee) revert MaxFeeExceeded(_maxFee, fee);
        _addUnclaimedRewards(fee);

        // The actual withdrawal amount is the sent value minus the fee.
        uint256 withdrawalAmount = msg.value - fee;
        // Revert if the withdrawal amount does not match the required decimal scaling factor.
        if ((withdrawalAmount % (10 ** config.decimalScalingFactor)) != 0) revert InvalidAmount();
        // Revert if the withdrawal amount is outside the allowed range.
        if (withdrawalAmount < config.minAmount) revert AmountBelowMinAmount(config.minAmount, withdrawalAmount);
        if (withdrawalAmount > config.maxAmount) revert AmountExceedsMaxAmount(config.maxAmount, withdrawalAmount);

        uint256 amountForHashing = withdrawalAmount / (10 ** config.decimalScalingFactor);

        StorageTypes.State memory state = _getNativeBridgeWithdrawalState();
        uint256 newNonce = state.nonce + 1;
        bytes32 withdrawalHash = NativeBridgeLib._hashNativeBrideOp(newNonce, _to, amountForHashing);
        bytes32 newRoot = BridgeLib._computeNewRoot(state.root, withdrawalHash);
        _setNativeBridgeWithdrawalState(StorageTypes.State({nonce: newNonce, root: newRoot}));
        emit NativeWithdrawal(newNonce, _to, amountForHashing, msg.sender, withdrawalHash, newRoot);
    }

    function setNativeWithdrawalFee(uint256 _fee) external onlyGovernor {
        _setNativeWithdrawalFee(_fee);
        emit NativeWithdrawalFeeChange(_fee);
    }

    function setMinNativeWithdrawalAmount(uint256 _amount) external onlyGovernor {
        _setNativeWithdrawalMinAmount(_amount);
        emit MinNativeWithdrawalChange(_amount);
    }

    function setMaxNativeWithdrawalAmount(uint256 _amount) external onlyGovernor {
        _setNativeWithdrawalMaxAmount(_amount);
        emit MaxNativeWithdrawalChange(_amount);
    }

    function setMaxNativeDeposits(uint256 _maxNrDeposits) external onlyGovernor {
        _setMaxNativeDeposits(_maxNrDeposits);
        emit MaxNativeDepositsChange(_maxNrDeposits);
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
    )
        external
        override
        onlyGovernor
    {
        if (_neoXToken == address(0)) revert InvalidTokenAddress();
        if (!TokenBridgeLib._isValidConfig(_tokenConfig)) revert InvalidTokenConfig();
        _registerToken(_neoXToken, _tokenConfig);
        emit TokenRegister(_neoXToken, _tokenConfig);
    }

    /**
     * @notice Check if a token is registered on the bridge.
     * @param _neoXToken the address of the token on the Neo X network.
     */
    function isRegisteredToken(address _neoXToken) external view override returns (bool) {
        return _isRegisteredToken(_neoXToken);
    }

    /**
     * @notice Pause a token bridge. No deposits, withdrawals, or claims of a token bridge can be made while it is locked.
     * @param _neoXToken the address of the token on the Neo X network.
     */
    function pauseTokenBridge(address _neoXToken)
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
    function unpauseTokenBridge(address _neoXToken)
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
        StorageTypes.State memory depositState = _getTokenDepositState(_neoXToken);
        StorageTypes.TokenConfig memory config = _getTokenConfig(_neoXToken);

        // Check parameter validity
        uint256 depositLength = _deposits.length;
        if (depositLength == 0) revert InvalidDepositsLength();
        if (depositLength > config.maxDeposits) revert InvalidDepositsLength();
        // Check if provided deposit data's nonces are subsequent to the current nonce and each other.
        if (!BridgeLib._subsequentNonces(_deposits, depositState.nonce)) revert InvalidNonceSequence();
        // Validate that the provided token deposit root is equal to the new computed root based on the provided deposits.
        if (
            TokenBridgeLib._computeNewTopRoot(depositState.root, _getNeoN3Token(_neoXToken), _neoXToken, _deposits)
                != _tokenDepositRoot
        ) revert InvalidRoot();
        // Verify that the provided signatures are valid given the provided deposit root and the current validators.
        if (!management.verifyValidatorSignatures(_tokenDepositRoot, _signatures)) revert InvalidValidatorSignatures();

        // Update the token's deposit state
        _setTokenDepositState(
            _neoXToken, StorageTypes.State({nonce: _deposits[depositLength - 1].nonce, root: _tokenDepositRoot})
        );
        emit TokenDepositRootUpdate(
            _neoXToken, config.neoN3Token, _deposits[depositLength - 1].nonce, _tokenDepositRoot
        );

        // Execute the token distribution
        _executeTokenDistribution(_neoXToken, config.decimalScalingFactor, _deposits);
    }

    function _executeTokenDistribution(
        address _neoXToken,
        uint256 _decimalScalingFactor,
        BridgeLib.DepositData[] calldata _deposits
    )
        private
    {
        uint256 depositLength = _deposits.length;
        // Execute the token distribution for each deposit entry
        for (uint256 i = 0; i < depositLength; i++) {
            BridgeLib.DepositData calldata depositEntry = _deposits[i];
            address to = depositEntry.to;
            uint256 transferAmount = depositEntry.amount;
            if (_decimalScalingFactor > 0) transferAmount *= (10 ** _decimalScalingFactor);
            bool success = TokenBridgeLib._safeERC20Transfer(IERC20(_neoXToken), to, transferAmount);
            _emitTransferEventOrAddNewTokenClaimable(success, _neoXToken, depositEntry.nonce, to, transferAmount);
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
        StorageTypes.Claimable memory claimable = _getTokenClaimable(_neoXToken, _nonce);
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
    )
        private
    {
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

        uint256 receivedAmount = _transferERC20TokenToBridge(_neoXToken, from, _amount);
        // Check that the received amount is in the allowed range.
        if (receivedAmount < config.minAmount) revert AmountBelowMinAmount(config.minAmount, receivedAmount);
        if (receivedAmount > config.maxAmount) revert AmountExceedsMaxAmount(config.maxAmount, receivedAmount);

        // Compute the new root and update the token withdrawal state.
        StorageTypes.State memory state = _getTokenWithdrawalState(_neoXToken);
        uint256 newNonce = state.nonce + 1;

        if (config.decimalScalingFactor > 0) {
            uint256 scalingFactor = 10 ** config.decimalScalingFactor;
            if (receivedAmount % scalingFactor != 0) revert InvalidAmount();
            receivedAmount /= scalingFactor;
        }

        bytes32 withdrawalHash =
            TokenBridgeLib._hashTokenBridgeOp(config.neoN3Token, _neoXToken, newNonce, _to, receivedAmount);
        bytes32 newRoot = BridgeLib._computeNewRoot(state.root, withdrawalHash);
        _setTokenWithdrawalState(_neoXToken, StorageTypes.State({nonce: newNonce, root: newRoot}));
        emit TokenWithdrawal(
            _neoXToken, config.neoN3Token, newNonce, _to, receivedAmount, from, withdrawalHash, newRoot
        );
    }

    /**
     * @dev Checks the provided value against the required fee. If the provided value exceeds the required fee, the
     * excess amount is refunded if the sender is an EOA. Otherwise, if the sender is a contract, it is reverted.
     * @param _from the sender.
     * @param _msgValue the value sent with the transaction.
     * @param _fee the required fee.
     */
    function _processTokenWithdrawalFee(address _from, uint256 _msgValue, uint256 _fee) private {
        // Revert if the provided value is lower than the required fee.
        if (_msgValue < _fee) revert InsufficientFee(_fee, _msgValue);
        // Refund the sender (only EOAs) if the provided value is higher than the required fee.
        if (_msgValue > _fee) {
            // Revert if the sender is a contract.
            if (BridgeLib._isContract(_from)) revert ExactFeeRequired(_fee, _msgValue);
            (bool success,) = payable(_from).call{value: _msgValue - _fee}("");
            if (!success) revert TransferFailed();
        }
        _addUnclaimedRewards(_fee);
    }

    function _transferERC20TokenToBridge(
        address _neoXToken,
        address _from,
        uint256 _amount
    )
        private
        returns (uint256 actualReceivedAmount)
    {
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
    )
        external
        override
        onlyGovernor
    {
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
    )
        external
        override
        onlyGovernor
    {
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
    )
        external
        override
        onlyGovernor
    {
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
    )
        external
        override
        onlyGovernor
    {
        uint256 nrTokens = _neoXTokens.length;
        if (nrTokens != _maxDeposits.length) revert LengthMismatch();
        for (uint256 i = 0; i < nrTokens; i++) {
            uint256 maxDeposits = _maxDeposits[i];
            _setMaxTokenDeposits(_neoXTokens[i], maxDeposits);
            emit MaxTokenDepositsChange(_neoXTokens[i], maxDeposits);
        }
    }

    // Migration functionality
    // commented until a reinitialization is needed
    // function upgradeToV<version_nr>() external virtual reinitializer(<version_nr>) onlyAdmin {
    //     _upgradeToV<version_nr>();
    // }

    // IMessageBridge Implementation

    /**
     * @notice Check if the message bridge is set up.
     */
    function messageBridgeIsSet() external view override returns (bool) {
        return _messageBridgeIsSet();
    }

    /**
     * @notice Set up the message bridge with configuration parameters.
     * @param _fee the fee for using the message bridge.
     * @param _maxMessageSize the maximum allowed size of a message in bytes.
     * @param _maxNrMessages the maximum number of messages that can be processed in a single transaction.
     */
    function setMessageBridge(
        uint256 _fee,
        uint256 _maxMessageSize,
        uint256 _maxNrMessages
    )
        external
        override
        onlyGovernor
    {
        _setMessageBridge(_fee, _maxMessageSize, _maxNrMessages);
        emit MessageBridgeRegister(
            StorageTypes.MessageConfig({fee: _fee, maxMessageSize: _maxMessageSize, maxNrMessages: _maxNrMessages})
        );
    }

    /**
     * @notice Pause the message bridge. No message deposits can be made while the bridge is paused.
     */
    function pauseMessageBridge()
        external
        override
        onlyGovernorOrSecurityGuard
        onlyIfMessageBridgeSet
        whenMessageBridgeNotPaused
    {
        _pauseMessageBridge();
        emit MessageBridgePause();
    }

    /**
     * @notice Unpause the message bridge. Message deposits can be made after unpausing.
     */
    function unpauseMessageBridge() external override onlyGovernor onlyIfMessageBridgeSet whenMessageBridgePaused {
        _unpauseMessageBridge();
        emit MessageBridgeUnpause();
    }

    /**
     * @notice Processes messages that have been sent from the other chain.
     * @dev The depositMessage function is used to process messages that have been sent from the other chain.
     *      The messages need to be provided ordered based on their nonces.
     *      Before the messages are processed, the following steps are executed:
     *      - Check if the provided messages array is not empty and within the allowed maximum.
     *      - Check if the computed root based on the provided messages matches the provided root.
     *      - Check if the provided signatures are valid given the provided root and the current validators.
     *      Once these checks are passed, the storage state is updated with the new nonce and root, and the messages are stored.
     * @param _depositRoot the new deposit root.
     * @param _signatures the signatures of the validators. The signatures need to be ordered.
     * @param _messages the message data containing nonces and message contents.
     */
    function storeMessage(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        StorageTypes.MessageData[] calldata _messages
    )
        external
        override
        onlyRelayer
        whenBridgeNotPaused
        onlyIfMessageBridgeSet
        whenMessageBridgeNotPaused
        nonReentrant
    {
        StorageTypes.State memory state = _getMessageBridgeN3ToEvmState();
        StorageTypes.MessageConfig memory config = _getMessageBridgeConfig();

        // Check parameter validity
        uint256 messageLength = _messages.length;
        if (messageLength == 0) revert InvalidDepositsLength();
        if (messageLength > config.maxNrMessages) revert InvalidDepositsLength();

        // Check if nonces are in sequence
        // More gas-efficient nonce validation that doesn't update a variable on each iteration
        // Each nonce should be exactly (state.nonce + position in array + 1)
        for (uint256 i = 0; i < messageLength; i++) {
            if (_messages[i].nonce != state.nonce + i + 1) revert InvalidNonceSequence();
        }

        // Validate that the provided message deposit root is equal to the computed root
        if (MessageBridgeLib._computeNewTopRoot(state.root, _messages) != _depositRoot) revert InvalidRoot();

        // Verify that the provided signatures are valid
        if (!management.verifyValidatorSignatures(_depositRoot, _signatures)) revert InvalidValidatorSignatures();

        // Update the message bridge deposit state
        _setMessageBridgeN3ToEvmState(
            StorageTypes.State({nonce: _messages[messageLength - 1].nonce, root: _depositRoot})
        );
        emit MessageDepositRootUpdate(_messages[messageLength - 1].nonce, _depositRoot);

        // TODO: extract to a private function
        for (uint256 i = 0; i < messageLength; i++) {
            StorageTypes.MessageData calldata messageData = _messages[i];
            if (n3ToEvmMessages[messageData.nonce].target != address(0)) revert MessageAlreadyExists(messageData.nonce);
            // Decode the message bytes into a Call struct and store it directly
            n3ToEvmMessages[messageData.nonce] = abi.decode(messageData.message, (StorageTypes.Call));
            emit MessageDeposit(messageData.nonce, messageData.message);
        }
    }

    function executeMessage(uint256 nonce) public payable returns (StorageTypes.Result memory) {
        StorageTypes.Call memory call = n3ToEvmMessages[nonce];
        if (call.target == address(0)) revert MessageNotFound(nonce);

        // Verify that the msg.value matches the call.value from the message
        if (msg.value != call.value) revert ValueMismatch(call.value, msg.value);

        StorageTypes.Result memory result;

        (result.success, result.returnData) = call.target.call{value: call.value}(call.callData);

        // forward the reason for failure if the call was not allowed to fail
        if (!call.allowFailure && !result.success) revert CallFailed(result.returnData);

        return result;
    }

    /**
     * @notice Set the fee for using the message bridge.
     * @param _fee the new fee.
     */
    function setMessageBridgeFee(uint256 _fee) external override onlyGovernor {
        _setMessageBridgeFee(_fee);
        emit MessageWithdrawalFeeChange(_fee);
    }

    /**
     * @notice Set the maximum allowed size of a message.
     * @param _maxSize the new maximum message size in bytes.
     */
    function setMaxMessageSize(uint256 _maxSize) external override onlyGovernor {
        _setMaxMessageSize(_maxSize);
        emit MaxMessageSizeChange(_maxSize);
    }

    /**
     * @notice Set the maximum number of messages that can be processed in a single transaction.
     * @param _maxNrMessages the new maximum number of messages.
     */
    function setMaxNrMessages(uint256 _maxNrMessages) external override onlyGovernor {
        _setMaxNrMessages(_maxNrMessages);
        emit MaxNrMessagesChange(_maxNrMessages);
    }
}

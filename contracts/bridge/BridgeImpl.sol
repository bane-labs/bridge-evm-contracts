// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgeStorage.sol";
import "../interfaces/IBridge.sol";
import "../interfaces/IGasBridge.sol";
import "../interfaces/ITokenBridge.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BridgeImpl is
    BridgeStorage,
    ReentrancyGuard,
    IBridge,
    IGasBridge,
    ITokenBridge
{
    receive() external payable onlyFunder {
        emit Fund(msg.value);
    }

    constructor(address _management) BridgeStorage(_management) {}

    // Contract Pausing

    function pauseBridge() external onlySecurityGuard onlyBridgeUnpaused {
        _pauseBridge();
        emit BridgePause();
    }

    function unpauseBridge() external onlyGovernor onlyBridgePaused {
        _unpauseBridge();
        emit BridgeUnpause();
    }

    // IGasBridge Implementation

    function pauseGasBridge()
        external
        override
        onlySecurityGuard
        onlyGasBridgeUnpaused
    {
        _pauseGasBridge();
        emit GasBridgePause();
    }

    function unpauseGasBridge()
        external
        override
        onlyGovernor
        onlyGasBridgePaused
    {
        _unpauseGasBridge();
        emit GasBridgeUnpause();
    }

    /**
     * @notice Distributes Gas that has been locked on Neo N3.
     * @dev The depositGas function is used to deposit funds to the bridge.
     *      The deposits data need to be provided ordered based on their nonces.
     *      Before the deposits are distributed, the following steps are executed:
     *      - Check if the provided deposits are subsequent to the current nonce in storage and each other.
     *      - Check if the computed root based on the provided deposits matches the provided root.
     *      - Check if the provided signatures are valid given the provided root and the current validators.
     *      Once these checks are passed, the storage state is updated with the new nonce and root, and the deposits are distributed.
     * @param _depositRoot the new deposit root.
     * @param _signatures the signatures of the validators.
     * @param _deposits the deposit data.
     */
    function depositGas(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    )
        external
        onlyRelayer
        onlyBridgeUnpaused
        onlyGasBridgeUnpaused
        nonReentrant
    {
        StorageTypes.State memory state = _getGasBridgeDepositState();
        StorageTypes.GasConfig memory config = _getGasBridgeConfig();
        uint depositLength = _deposits.length;
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
        // Execution data interface
        _executeGasTransfers(_deposits);
    }

    function _executeGasTransfers(
        BridgeLib.DepositData[] calldata _deposits
    ) private {
        uint depositLength = _deposits.length;
        for (uint i = 0; i < depositLength; i++) {
            BridgeLib.DepositData calldata depositEntry = _deposits[i];
            address to = depositEntry.to;
            if (BridgeLib._isContract(to)) {
                _addClaimableGas(depositEntry.nonce, depositEntry.amount, to);
                emit GasClaimable(depositEntry.nonce, depositEntry.amount, to);
            } else {
                uint256 sendValue = GasBridgeLib._addTenDecimals(
                    depositEntry.amount
                );
                (bool success, ) = to.call{value: sendValue}("");
                if (success) {
                    emit GasDeposit(
                        depositEntry.nonce,
                        depositEntry.amount,
                        to
                    );
                } else {
                    _addClaimableGas(
                        depositEntry.nonce,
                        depositEntry.amount,
                        to
                    );
                    emit GasClaimable(
                        depositEntry.nonce,
                        depositEntry.amount,
                        to
                    );
                }
            }
        }
    }

    // Anyone can execute a claim. The funds of a claimable will be sent to the defined address in the claimableTo mapping.
    function claimGas(
        uint256 _nonce
    ) external onlyBridgeUnpaused onlyGasBridgeUnpaused nonReentrant {
        StorageTypes.Claimable memory claimable = _getGasClaimable(_nonce);
        uint256 amount = claimable.amount;
        address to = claimable.to;
        if (amount == 0) revert NonexistentClaimable();
        if (to == address(0)) revert NonexistentClaimable();

        _deleteGasClaimable(_nonce);
        uint256 sendValue = GasBridgeLib._addTenDecimals(amount);
        (bool success, ) = to.call{value: sendValue}("");
        if (!success) revert TransferFailed();
        emit GasClaim(_nonce, amount, to);
    }

    function withdrawGas(
        address _to
    ) external payable onlyBridgeUnpaused onlyGasBridgeUnpaused {
        if (_to == address(0)) revert InvalidAddress();
        if ((msg.value % 1e10) != 0) revert InvalidAmount();
        StorageTypes.GasConfig memory config = _getGasBridgeConfig();
        StorageTypes.State memory state = _getGasBridgeWithdrawalState();
        uint256 actualWithdrawalAmount = msg.value - config.fee;
        if (actualWithdrawalAmount < config.minAmount) revert InvalidAmount();
        if (actualWithdrawalAmount > config.maxAmount) revert InvalidAmount();

        uint256 amountForHashing = GasBridgeLib._removeTenDecimals(
            actualWithdrawalAmount
        );
        uint256 newNonce = state.nonce + 1;
        bytes32 withdrawalHash = GasBridgeLib._hashGasBrideOp(
            newNonce,
            amountForHashing,
            _to
        );
        bytes32 newRoot = BridgeLib._computeNewRoot(state.root, withdrawalHash);
        _setGasBridgeWithdrawalState(
            StorageTypes.State({nonce: newNonce, root: newRoot})
        );
        emit GasWithdrawal(
            newNonce,
            amountForHashing,
            _to,
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

    function setMaxGasDeposits(uint8 _maxNrDeposits) external onlyGovernor {
        _setMaxGasDeposits(_maxNrDeposits);
        emit MaxGasDepositsChange(_maxNrDeposits);
    }

    // ITokenBridge Implementation

    /**
     * @notice Register a new token bridge.
     * @param _neoXToken the address of the token on the Neo X network.
     * @param _tokenConfig the configuration of the token bridge.
     */
    function registerToken(
        address _neoXToken,
        StorageTypes.TokenConfig calldata _tokenConfig
    ) external override {
        if (_neoXToken == address(0)) revert InvalidTokenAddress();
        if (_tokenConfig.minAmount > _tokenConfig.maxAmount)
            revert InvalidAmount();
        if (_tokenConfig.neoN3Token == address(0)) revert InvalidAddress();

        _registerToken(_neoXToken, _tokenConfig);
        emit TokenRegister(_neoXToken, _tokenConfig);
    }

    /**
     * @notice Unregister a token bridge.
     * @param _neoXToken the address of the token on the Neo X network.
     */
    function unregisterToken(
        address _neoXToken
    ) external override onlyGovernor onlyTokenBridgePaused(_neoXToken) {
        _unregisterToken(_neoXToken);
        emit TokenUnregister(_neoXToken, _getNeoN3Token(_neoXToken));
    }

    /**
     * @notice Pause a token bridge. No deposits, withdrawals, or claims of a token bridge can be made while it is locked.
     * @param _neoXToken the address of the token on the Neo X network.
     */
    function pauseTokenBridge(
        address _neoXToken
    ) external override onlyTokenBridgeUnpaused(_neoXToken) onlyGovernor {
        _pauseToken(_neoXToken);
        emit TokenPause(_neoXToken, _getNeoN3Token(_neoXToken));
    }

    /**
     * @notice Unpause a token bridge. Deposits, withdrawals, or claims of a token bridge can only be made while it is unlocked.
     * @param _neoXToken the address of the token on the Neo X network.
     */
    function unpauseTokenBridge(
        address _neoXToken
    ) external override onlyTokenBridgePaused(_neoXToken) onlyGovernor {
        _unpauseToken(_neoXToken);
        emit TokenPause(_neoXToken, _getNeoN3Token(_neoXToken));
    }

    function depositToken(
        address _neoXToken,
        bytes32 _tokenDepositRoot,
        BridgeLib.Signature[] calldata _signatures,
        BridgeLib.DepositData[] calldata _deposits
    )
        external
        override
        onlyBridgeUnpaused
        onlyTokenBridgeUnpaused(_neoXToken)
        nonReentrant
    {
        StorageTypes.State memory depositState = _getTokenDepositState(
            _neoXToken
        );
        StorageTypes.TokenConfig memory config = _getTokenConfig(_neoXToken);

        // Check parameter validity
        uint depositLength = _deposits.length;
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

        // Execute the token distribution
        _executeTokenDistribution(_neoXToken, config.tokenType, _deposits);
    }

    function _executeTokenDistribution(
        address _neoXToken,
        StorageTypes.TokenType _tokenType,
        BridgeLib.DepositData[] calldata _deposits
    ) private {
        uint depositLength = _deposits.length;
        // Execute the token distribution for each deposit entry
        for (uint i = 0; i < depositLength; i++) {
            BridgeLib.DepositData calldata depositEntry = _deposits[i];
            address to = depositEntry.to;
            uint256 transferAmount = depositEntry.amount;
            bool success = false;
            if (_tokenType == StorageTypes.TokenType.ERC20Capped) {
                // Execute the token distribution for ERC20Capped tokens
                IERC20 neoXToken = IERC20(_neoXToken);
                success = _executeERC20Transfer(neoXToken, transferAmount, to);
            } else if (_tokenType == StorageTypes.TokenType.NEO) {
                // Execute the token distribution for NEO tokens
                // For NEO tokens, the transfer value needs to be extended with 18 decimals, since it's nondivisible on Neo N3 and it has 18 decimals on Neo X.
                transferAmount *= 1e18;
                IERC20 neoXToken = IERC20(_neoXToken);
                success = _executeERC20Transfer(neoXToken, transferAmount, to);
            }
            // For future token types add an else if block here
            else {
                assert(false);
            }
            _emitTransferEventOrAddNewTokenClaimable(
                success,
                _neoXToken,
                depositEntry.nonce,
                transferAmount,
                to
            );
        }
    }

    function claimToken(
        address _neoXToken,
        uint256 _nonce
    )
        external
        override
        onlyBridgeUnpaused
        onlyTokenBridgeUnpaused(_neoXToken)
        nonReentrant
    {
        StorageTypes.Claimable memory claimable = _getTokenClaimable(
            _neoXToken,
            _nonce
        );
        // Check if the claimable exists.
        address to = claimable.to;
        if (to == address(0)) revert NonexistentClaimable();
        _deleteTokenClaimable(_neoXToken, _nonce);
        StorageTypes.TokenType tokenType = _getTokenType(_neoXToken);
        if (
            tokenType == StorageTypes.TokenType.NEO ||
            tokenType == StorageTypes.TokenType.ERC20Capped
        ) {
            // Note: For NEO tokens, the transfer value has already been extended with 18 decimals in the deposit function.
            IERC20 neoXToken = IERC20(_neoXToken);
            _executeERC20Transfer(neoXToken, claimable.amount, to);
        } else {
            assert(false);
        }
    }

    function _emitTransferEventOrAddNewTokenClaimable(
        bool _success,
        address _neoXToken,
        uint256 _nonce,
        uint256 _amount,
        address _to
    ) private {
        if (_success) {
            emit TokenDeposit(_neoXToken, _nonce, _amount, _to);
        } else {
            _addTokenClaimable(_neoXToken, _nonce, _amount, _to);
            emit TokenClaimable(_neoXToken, _nonce, _amount, _to);
        }
    }

    function _executeERC20Transfer(
        IERC20 _neoXToken,
        uint256 _amount,
        address _to
    ) private returns (bool) {
        return _neoXToken.transfer(_to, _amount);
    }

    /**
     * @notice Withdraw tokens to Neo N3.
     * @dev This function must be called by the contract that is registered and thus is responsible for bridging the tokens. This can but need not be the token contract itself.
     * @param _amount the amount of tokens to withdraw.
     * @param _to the address to which the tokens should be sent.
     */
    function withdrawToken(
        uint256 _amount,
        address _to
    )
        external
        payable
        override
        onlyBridgeUnpaused
        onlyTokenBridgeUnpaused(msg.sender)
    {
        address tokenAddress = msg.sender;
        if (_isRegisteredToken(tokenAddress))
            revert TokenBridgeNotRegistered(tokenAddress);
        StorageTypes.TokenConfig memory config = _getTokenConfig(tokenAddress);
        uint256 tokenValue = _amount;
        if (tokenValue < config.minAmount) revert InvalidAmount();
        if (tokenValue > config.maxAmount) revert InvalidAmount();

        if (msg.value < config.fee)
            revert InsufficientFee(msg.value, config.fee);

        // Compute the new root and update the token withdrawal state.
        StorageTypes.State memory state = _getTokenWithdrawalState(
            tokenAddress
        );
        uint256 newNonce = state.nonce + 1;

        if (config.tokenType == StorageTypes.TokenType.NEO) {
            if (tokenValue % 1e18 != 0) {
                revert InvalidAmount();
            } else {
                tokenValue /= 1e18;
            }
        }

        bytes32 withdrawalHash = TokenBridgeLib._hashTokenBridgeOp(
            config.neoN3Token,
            tokenAddress,
            newNonce,
            tokenValue,
            _to
        );
        bytes32 newRoot = BridgeLib._computeNewRoot(state.root, withdrawalHash);
        _setTokenWithdrawalState(
            tokenAddress,
            StorageTypes.State({nonce: newNonce, root: newRoot})
        );
        emit TokenWithdrawal(tokenAddress, newNonce, tokenValue, _to);
    }

    function setMinTokenWithdrawalAmount(
        address[] calldata _neoXTokens,
        uint256[] calldata _minAmounts
    ) external override onlyGovernor {
        uint len = _neoXTokens.length;
        if (len != _minAmounts.length) revert LengthMismatch();
        for (uint i = 0; i < len; i++) {
            address token = _neoXTokens[i];
            uint256 minAmount = _minAmounts[i];
            _setTokenMinWithdrawalAmount(token, minAmount);
            emit MinTokenWithdrawalAmountChange(token, minAmount);
        }
    }

    function setMaxTokenWithdrawalAmount(
        address[] calldata _neoXTokens,
        uint256[] calldata _maxAmounts
    ) external override onlyGovernor {
        uint len = _neoXTokens.length;
        if (len != _maxAmounts.length) revert LengthMismatch();
        for (uint i = 0; i < len; i++) {
            address token = _neoXTokens[i];
            uint256 maxAmount = _maxAmounts[i];
            _setTokenMaxWithdrawalAmount(token, maxAmount);
            emit MaxTokenWithdrawalAmountChange(token, maxAmount);
        }
    }

    function setTokenWithdrawalFee(
        address[] calldata _neoXTokens,
        uint256[] calldata _fees
    ) external override onlyGovernor {
        uint len = _neoXTokens.length;
        if (len != _fees.length) revert LengthMismatch();
        for (uint i = 0; i < len; i++) {
            address token = _neoXTokens[i];
            uint256 fee = _fees[i];
            _setTokenWithdrawalFee(token, fee);
            emit TokenWithdrawalFeeChange(token, fee);
        }
    }
}

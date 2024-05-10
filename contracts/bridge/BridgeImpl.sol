// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgeStorage.sol";
import "../interfaces/IBridge.sol";
import "../interfaces/IGasBridge.sol";
import "../interfaces/ITokenBridge.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * When generating the bytecode for genesis script:
 * - set initial storage values in BridgeStorage.sol
 */
contract BridgeImpl is BridgeStorage, IBridge, IGasBridge, ITokenBridge {
    receive() external payable onlyFunder {
        emit Fund(msg.value);
    }

    constructor(address _management) BridgeStorage(_management) {}

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
        onlyBridgeUnlocked
        onlyGasBridgeUnlocked
        nonReentrant
    {
        StorageTypes.State memory state = _getGasBridgeDepositState();
        StorageTypes.GasConfig memory config = _getGasBridgeConfig();
        uint depositLength = _deposits.length;
        if (depositLength == 0) revert InvalidDepositsLength();
        if (depositLength > config.maxDepositsPerDistribution)
            revert InvalidDepositsLength();
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
        // Once this is reached, execute the deposits
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
                // Todo: Verify that this call works as expected, i.e., the funds have not been sent if it returns false.
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
    ) external onlyBridgeUnlocked onlyGasBridgeUnlocked nonReentrant {
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
    ) external payable onlyBridgeUnlocked onlyGasBridgeUnlocked {
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

    // Contract Locking

    function lockBridge() external onlySecurityGuard onlyBridgeUnlocked {
        _lockBridge();
        emit BridgeLock();
    }

    function unlockBridge() external onlyGovernor onlyBridgeLocked {
        _unlockBridge();
        emit BridgeUnlock();
    }

    // Bridge Parameter Setters

    function setGasWithdrawalFee(uint256 _fee) external onlyGovernor {
        _setGasWithdrawalFee(_fee);
        emit GasWithdrawalFeeChange(_fee);
    }

    function setGasWithdrawalMinAmount(uint256 _amount) external onlyGovernor {
        _setGasWithdrawalMinAmount(_amount);
        emit MinGasWithdrawalChange(_amount);
    }

    function setGasWithdrawalMaxAmount(uint256 _amount) external onlyGovernor {
        _setGasWithdrawalMaxAmount(_amount);
        emit MaxGasWithdrawalChange(_amount);
    }

    function setGasMaxNrDepositsPerDistribution(
        uint8 _maxNrDeposits
    ) external onlyGovernor {
        _setGasMaxNrDepositsPerDistribution(_maxNrDeposits);
        emit MaxGasDepositsPerDistributionChange(_maxNrDeposits);
    }

    // ITokenBridge Implementation

    /**
     * @notice Register a new token bridge.
     * @param _neoXTokenAddress the address of the token on the Neo X network.
     * @param _tokenType the type of token that is being registered.
     * @param _tokenConfig the configuration of the token bridge.
     */
    function registerToken(
        address _neoXTokenAddress,
        StorageTypes.TokenType _tokenType,
        StorageTypes.TokenConfig calldata _tokenConfig
    ) external override {
        if (_neoXTokenAddress == address(0)) revert InvalidTokenAddress();
        if (_tokenConfig.minAmount > _tokenConfig.maxAmount)
            revert InvalidAmount();
        if (_tokenConfig.neoN3TokenAddress == address(0))
            revert InvalidAddress();

        _registerToken(_neoXTokenAddress, _tokenType, _tokenConfig);
        emit TokenRegister(_neoXTokenAddress, _tokenType, _tokenConfig);
    }

    /**
     * @notice Unregister a token bridge.
     * @param _neoXTokenAddress the address of the token on the Neo X network.
     */
    function unregisterToken(
        address _neoXTokenAddress
    ) external override onlyGovernor onlyTokenBridgeLocked(_neoXTokenAddress) {
        _unregisterToken(_neoXTokenAddress);
        emit TokenUnregister(
            _neoXTokenAddress,
            _getNeoN3TokenAddress(_neoXTokenAddress)
        );
    }

    /**
     * @notice Lock a token bridge. No deposits, withdrawals, or claims of a token bridge can be made while it is locked.
     * @param _neoXTokenAddress the address of the token on the Neo X network.
     */
    function lockToken(
        address _neoXTokenAddress
    )
        external
        override
        onlyTokenBridgeUnlocked(_neoXTokenAddress)
        onlyGovernor
    {
        _lockToken(_neoXTokenAddress);
        emit TokenLock(
            _neoXTokenAddress,
            _getNeoN3TokenAddress(_neoXTokenAddress)
        );
    }

    /**
     * @notice Unlock a token bridge. Deposits, withdrawals, or claims of a token bridge can only be made while it is unlocked.
     * @param _neoXTokenAddress the address of the token on the Neo X network.
     */
    function unlockToken(
        address _neoXTokenAddress
    ) external override onlyTokenBridgeLocked(_neoXTokenAddress) onlyGovernor {
        _unlockToken(_neoXTokenAddress);
        emit TokenUnlock(
            _neoXTokenAddress,
            _getNeoN3TokenAddress(_neoXTokenAddress)
        );
    }

    function setTokenWithdrawalMinAmount(
        address _neoXTokenAddress,
        uint256 _minAmount
    ) external override onlyGovernor {
        _setTokenMinWithdrawalAmount(_neoXTokenAddress, _minAmount);
        emit TokenMinWithdrawalAmountChange(_neoXTokenAddress, _minAmount);
    }

    function setTokenWithdrawalMaxAmount(
        address _neoXTokenAddress,
        uint256 _maxAmount
    ) external override onlyGovernor {
        _setTokenMaxWithdrawalAmount(_neoXTokenAddress, _maxAmount);
        emit TokenMaxWithdrawalAmountChange(_neoXTokenAddress, _maxAmount);
    }

    function setTokenTypeConfig(
        StorageTypes.TokenType _tokenType,
        StorageTypes.TokenTypeConfig calldata _tokenTypeConfig
    ) external override onlyGovernor {
        _setTokenTypeConfig(_tokenType, _tokenTypeConfig);
        emit TokenTypeConfigChange(_tokenType, _tokenTypeConfig);
    }

    function depositToken(
        address _neoXTokenAddress,
        BridgeLib.DepositData[] calldata _deposits,
        bytes32 _tokenDepositRoot,
        BridgeLib.Signature[] calldata _signatures
    )
        external
        override
        onlyBridgeUnlocked
        onlyTokenBridgeUnlocked(_neoXTokenAddress)
        nonReentrant
    {
        StorageTypes.State memory depositState = _getTokenDepositState(
            _neoXTokenAddress
        );
        StorageTypes.TokenType tokenType = _getTokenType(_neoXTokenAddress);
        StorageTypes.TokenTypeConfig
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
            TokenBridgeLib._computeNewTopRoot(
                depositState.root,
                _getNeoN3TokenAddress(_neoXTokenAddress),
                _neoXTokenAddress,
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
            _neoXTokenAddress,
            StorageTypes.State({
                nonce: _deposits[depositLength - 1].nonce,
                root: _tokenDepositRoot
            })
        );

        // Execute the token distribution
        _executeTokenDistribution(_neoXTokenAddress, tokenType, _deposits);
    }

    function _executeTokenDistribution(
        address _neoXTokenAddress,
        StorageTypes.TokenType _tokenType,
        BridgeLib.DepositData[] calldata _deposits
    ) private {
        uint depositLength = _deposits.length;
        // Execute the token distribution for each deposit entry
        for (uint i = 0; i < depositLength; i++) {
            BridgeLib.DepositData calldata depositEntry = _deposits[i];
            address to = depositEntry.to;
            bool success = false;
            if (_tokenType == StorageTypes.TokenType.ERC20Capped) {
                // Execute the token distribution for ERC20Capped tokens
                IERC20 tokenContract = IERC20(_neoXTokenAddress);
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
                _neoXTokenAddress,
                depositEntry.nonce,
                depositEntry.amount,
                to
            );
        }
    }

    function claimToken(
        address _neoXTokenAddress,
        uint256 _nonce
    )
        external
        override
        onlyBridgeUnlocked
        onlyTokenBridgeUnlocked(_neoXTokenAddress)
        nonReentrant
    {
        StorageTypes.Claimable memory claimable = _getTokenClaimable(
            _neoXTokenAddress,
            _nonce
        );
        // Check if the claimable exists.
        if (claimable.to == address(0)) revert NonexistentClaimable();
        _deleteTokenClaimable(_neoXTokenAddress, _nonce);
        if (
            _getTokenType(_neoXTokenAddress) ==
            StorageTypes.TokenType.ERC20Capped
        ) {
            IERC20 tokenContract = IERC20(_neoXTokenAddress);
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
        address _neoXTokenAddress,
        uint256 _nonce,
        uint256 _amount,
        address _to
    ) private {
        if (_success) {
            emit TokenDeposit(_neoXTokenAddress, _nonce, _amount, _to);
        } else {
            _addTokenClaimable(_neoXTokenAddress, _nonce, _amount, _to);
            emit TokenClaimable(_neoXTokenAddress, _nonce, _amount, _to);
        }
    }

    function _executeERC20CappedTransfer(
        IERC20 _tokenContract,
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
    function withdrawToken(
        uint256 _amount,
        address _to
    )
        external
        payable
        override
        onlyBridgeUnlocked
        onlyTokenBridgeUnlocked(msg.sender)
    {
        address tokenAddress = msg.sender;
        if (_isRegisteredToken(tokenAddress))
            revert TokenBridgeNotRegistered(tokenAddress);
        StorageTypes.TokenConfig memory config = _getTokenConfig(tokenAddress);
        if (_amount < config.minAmount) revert InvalidAmount();
        if (_amount > config.maxAmount) revert InvalidAmount();

        uint256 fee = _getWithdrawalFee(tokenAddress);
        if (msg.value < fee) revert InsufficientFee(msg.value, fee);

        // Compute the new root and update the token withdrawal state.
        StorageTypes.State memory state = _getTokenWithdrawalState(
            tokenAddress
        );
        uint256 newNonce = state.nonce + 1;
        bytes32 withdrawalHash = TokenBridgeLib._hashTokenBridgeOp(
            config.neoN3TokenAddress,
            tokenAddress,
            newNonce,
            _amount,
            _to
        );
        bytes32 newRoot = BridgeLib._computeNewRoot(state.root, withdrawalHash);
        _setTokenWithdrawalState(
            tokenAddress,
            StorageTypes.State({nonce: newNonce, root: newRoot})
        );
        emit TokenWithdrawal(tokenAddress, state.nonce, _amount, _to);
    }
}

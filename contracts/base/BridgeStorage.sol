// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../management/BridgeManagementImpl.sol";
import "../library/BridgeLib.sol";
import "../library/BridgeStorageTypes.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BridgeStorage is UUPSUpgradeable {
    address public constant SELF = 0x1212100000000000000000000000000000000004;
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    // Begin Storage Slots

    // General Bridge Parameters
    IBridgeManagement public management;
    bool public locked;
    // Gas Bridge
    BridgeStorageTypes.GasBridge public gasBridge;
    mapping(uint256 => BridgeStorageTypes.Claimable) public claimableGas;
    // Token Bridges
    mapping(uint256 identifier => BridgeStorageTypes.TokenBridge) public tokens;

    // End Storage Slots

    constructor(address _management) {
        management = IBridgeManagement(_management);
        gasBridge = BridgeStorageTypes.GasBridge({
            depositState: BridgeStorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: BridgeStorageTypes.State({nonce: 0, root: 0x0}),
            config: BridgeStorageTypes.GasConfig({
                fee: 10 ** 17,
                minAmount: 10 ** 18,
                maxAmount: 10 ** 22,
                maxDepositsPerDistribution: 100,
                gap: [uint256(0), uint256(0)]
            })
        });
    }

    error TokenAlreadyRegistered(uint256 identifier);
    error TokenNotRegistered(uint256 identifier);
    error InvalidAddress();
    error InvalidAmount();
    error InvalidDepositsLength();
    error InvalidFee();
    error InvalidNonceSequence();
    error InvalidRoot();
    error InvalidValidatorSignatures();
    error NonexistentClaimable();
    error TransferFailed();

    // Modifiers for Role Restriction

    modifier onlyRelayer() {
        require(msg.sender == management.getRelayer(), "not relayer");
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == management.getGovernor(), "not governor");
        _;
    }

    modifier onlySecurityGuard() {
        require(
            msg.sender == management.getSecurityGuard(),
            "not securityGuard"
        );
        _;
    }

    modifier onlyFunder() {
        require(msg.sender == management.getFunder(), "not funder");
        _;
    }

    modifier unlocked() {
        require(!locked, "contract locked");
        _;
    }

    modifier tokenUnlocked(uint256 _identifier) {
        require(!tokens[_identifier].locked, "token locked");
        _;
    }

    modifier tokenLocked(uint256 _identifier) {
        require(tokens[_identifier].locked, "token unlocked");
        _;
    }

    function _lock() internal {
        require(!locked, "already locked");
        locked = true;
    }

    function _unlock() internal {
        require(locked, "already unlocked");
        locked = false;
    }

    function _addClaimableGas(
        uint256 _nonce,
        uint256 _amount,
        address _to
    ) internal {
        claimableGas[_nonce] = BridgeStorageTypes.Claimable({
            to: _to,
            amount: _amount
        });
    }

    function _getGasClaimable(
        uint256 _nonce
    ) internal view returns (BridgeStorageTypes.Claimable memory) {
        return claimableGas[_nonce];
    }

    function _deleteGasClaimable(uint256 _nonce) internal {
        delete claimableGas[_nonce];
    }

    function _getGasBridgeConfig()
        internal
        view
        returns (BridgeStorageTypes.GasConfig memory config)
    {
        return gasBridge.config;
    }

    function _getGasBridgeDepositState()
        internal
        view
        returns (BridgeStorageTypes.State memory state)
    {
        return gasBridge.depositState;
    }

    function _setGasBridgeDepositState(
        BridgeStorageTypes.State memory state
    ) internal {
        gasBridge.depositState = state;
    }

    function _getGasBridgeWithdrawalState()
        internal
        view
        returns (BridgeStorageTypes.State memory state)
    {
        return gasBridge.withdrawalState;
    }

    function _setGasBridgeWithdrawalState(
        BridgeStorageTypes.State memory state
    ) internal {
        gasBridge.withdrawalState = state;
    }

    function _setGasWithdrawalFee(uint256 _fee) internal {
        if ((_fee % (10 ** 10)) != 0) revert InvalidFee();
        gasBridge.config.fee = _fee;
    }

    function _setGasWithdrawalMinAmount(uint256 _amount) internal {
        if ((_amount % (10 ** 10)) != 0) revert InvalidAmount();
        if (_amount >= gasBridge.config.maxAmount) revert InvalidAmount();
        gasBridge.config.minAmount = _amount;
    }

    function _setGasWithdrawalMaxAmount(uint256 _amount) internal {
        if ((_amount % (10 ** 10)) != 0) revert InvalidAmount();
        if (_amount <= gasBridge.config.minAmount) revert InvalidAmount();
        gasBridge.config.maxAmount = _amount;
    }

    function _setGasMaxNrDepositsPerDistribution(uint8 _maxDeposits) internal {
        if (_maxDeposits == 0) revert InvalidAmount();
        gasBridge.config.maxDepositsPerDistribution = _maxDeposits;
    }

    // Token Bridge functions

    function _registerToken(
        uint256 _identifier,
        BridgeStorageTypes.TokenType _tokenType,
        BridgeStorageTypes.TokenConfig memory _tokenConfig
    ) internal {
        // Check if token config contains valid values
        if (_tokenConfig.minAmount > _tokenConfig.maxAmount)
            revert InvalidAmount();
        if (_tokenConfig.contractAddress == address(0)) revert InvalidAddress();

        // Check if token bridge is already registered
        BridgeStorageTypes.TokenBridge memory tokenBridge = tokens[_identifier];
        if (tokenBridge.registered) revert TokenAlreadyRegistered(_identifier);
        // Add token bridge to storage
        tokens[_identifier] = BridgeStorageTypes.TokenBridge({
            registered: true,
            locked: false,
            tokenType: _tokenType,
            depositState: BridgeStorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: BridgeStorageTypes.State({nonce: 0, root: 0x0}),
            config: _tokenConfig
        });
    }

    function _unregisterToken(uint256 _identifier) internal {
        if (!tokens[_identifier].registered)
            revert TokenNotRegistered(_identifier);
        delete tokens[_identifier];
    }

    function _lockToken(uint256 _identifier) internal {
        if (!tokens[_identifier].registered)
            revert TokenNotRegistered(_identifier);
        tokens[_identifier].locked = true;
    }

    function _unlockToken(uint256 _identifier) internal {
        if (!tokens[_identifier].registered)
            revert TokenNotRegistered(_identifier);
        tokens[_identifier].locked = false;
    }

    // Upgrade authorization

    modifier onlyAdmin() {
        require(msg.sender == GOV_ADMIN, "not admin");
        _;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyAdmin {}

    // UUPSUpgradeable-specific functions required for precompiled version.

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC-1967 compliant implementation pointing to self.
     * See the modifier {onlyProxy} in UUPSUpgradeable.sol.
     *
     * Only for precompiled uups implementation in genesis file, need to be removed when upgrading the contract.
     * This override is added because "immutable __self" in UUPSUpgradeable is not avaliable in precompiled contract.
     */
    function _checkProxy() internal view virtual override {
        if (
            address(this) == SELF || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != SELF // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See the modifier {notDelegated} in UUPSUpgradeable.sol.
     *
     * Only for precompiled uups implementation in genesis file, need to be removed when upgrading the contract.
     * This override is added because "immutable __self" in UUPSUpgradeable is not avaliable in precompiled contract.
     */
    function _checkNotDelegated() internal view virtual override {
        if (address(this) != SELF) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeManagement.sol";
import "../library/BridgeLib.sol";
import "../library/GasBridgeLib.sol";
import "../library/StorageTypes.sol";
import "../library/TokenBridgeLib.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BridgeStorage is UUPSUpgradeable {
    address public constant SELF = 0x1212100000000000000000000000000000000004;
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    // Begin Storage Slots

    // General Bridge Parameters
    IBridgeManagement public management;
    bool public bridgeLocked;
    // Gas Bridge
    StorageTypes.GasBridge public gasBridge;
    mapping(uint256 => StorageTypes.Claimable) public claimableGas;
    // Token Bridges
    mapping(StorageTypes.TokenType tokenType => StorageTypes.TokenTypeConfig)
        public tokenTypeConfigs;
    mapping(address tokenAddress => StorageTypes.TokenBridge)
        public tokenBridges;
    mapping(address tokenAddress => mapping(uint256 nonce => StorageTypes.Claimable))
        public tokenClaimables;

    // End Storage Slots

    constructor(address _management) {
        management = IBridgeManagement(_management);
        gasBridge = StorageTypes.GasBridge({
            depositState: StorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: StorageTypes.State({nonce: 0, root: 0x0}),
            config: StorageTypes.GasConfig({
                fee: 1e17,
                minAmount: 1e18,
                maxAmount: 1e22,
                maxDepositsPerDistribution: 100,
                locked: false,
                gap: [uint256(0), uint256(0)]
            })
        });
    }

    error BridgeLocked();
    error BridgeUnlocked();
    error GasBridgeLocked();
    error GasBridgeUnlocked();
    error InsufficientFee(uint256 provided, uint256 minExpected);
    error InvalidAddress();
    error InvalidAmount();
    error InvalidDepositsLength();
    error InvalidFee();
    error InvalidTokenAddress();
    error InvalidNonceSequence();
    error InvalidRoot();
    error InvalidValidatorSignatures();
    error NonexistentClaimable();
    error TokenBridgeAlreadyRegistered(address neoXTokenAddress);
    error TokenBridgeLocked(address neoXTokenAddress);
    error TokenBridgeUnlocked(address neoXTokenAddress);
    error TokenBridgeNotRegistered(address neoXTokenAddress);
    error TokenWithdrawalFailed();
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

    modifier onlyBridgeUnlocked() {
        if (bridgeLocked) revert BridgeLocked();
        _;
    }

    modifier onlyBridgeLocked() {
        if (!bridgeLocked) revert BridgeUnlocked();
        _;
    }

    modifier onlyGasBridgeUnlocked() {
        if (gasBridge.config.locked) revert GasBridgeLocked();
        _;
    }

    modifier onlyGasBridgeLocked() {
        if (!gasBridge.config.locked) revert GasBridgeUnlocked();
        _;
    }

    modifier onlyTokenBridgeUnlocked(address _neoXTokenAddress) {
        if (tokenBridges[_neoXTokenAddress].locked)
            revert TokenBridgeLocked(_neoXTokenAddress);
        _;
    }

    modifier onlyTokenBridgeLocked(address _neoXTokenAddress) {
        if (!tokenBridges[_neoXTokenAddress].locked)
            revert TokenBridgeUnlocked(_neoXTokenAddress);
        _;
    }

    function _lockBridge() internal {
        bridgeLocked = true;
    }

    function _unlockBridge() internal {
        bridgeLocked = false;
    }

    function _addClaimableGas(
        uint256 _nonce,
        uint256 _amount,
        address _to
    ) internal {
        claimableGas[_nonce] = StorageTypes.Claimable({
            to: _to,
            amount: _amount
        });
    }

    function _getGasClaimable(
        uint256 _nonce
    ) internal view returns (StorageTypes.Claimable memory) {
        return claimableGas[_nonce];
    }

    function _deleteGasClaimable(uint256 _nonce) internal {
        delete claimableGas[_nonce];
    }

    function _getGasBridgeConfig()
        internal
        view
        returns (StorageTypes.GasConfig memory config)
    {
        return gasBridge.config;
    }

    function _getGasBridgeDepositState()
        internal
        view
        returns (StorageTypes.State memory state)
    {
        return gasBridge.depositState;
    }

    function _setGasBridgeDepositState(
        StorageTypes.State memory state
    ) internal {
        gasBridge.depositState = state;
    }

    function _getGasBridgeWithdrawalState()
        internal
        view
        returns (StorageTypes.State memory state)
    {
        return gasBridge.withdrawalState;
    }

    function _setGasBridgeWithdrawalState(
        StorageTypes.State memory state
    ) internal {
        gasBridge.withdrawalState = state;
    }

    function _setGasWithdrawalFee(uint256 _fee) internal {
        if ((_fee % 1e10) != 0) revert InvalidFee();
        gasBridge.config.fee = _fee;
    }

    function _setGasWithdrawalMinAmount(uint256 _amount) internal {
        if ((_amount % 1e10) != 0) revert InvalidAmount();
        if (_amount >= gasBridge.config.maxAmount) revert InvalidAmount();
        gasBridge.config.minAmount = _amount;
    }

    function _setGasWithdrawalMaxAmount(uint256 _amount) internal {
        if ((_amount % 1e10) != 0) revert InvalidAmount();
        if (_amount <= gasBridge.config.minAmount) revert InvalidAmount();
        gasBridge.config.maxAmount = _amount;
    }

    function _setGasMaxNrDepositsPerDistribution(uint8 _maxDeposits) internal {
        if (_maxDeposits == 0) revert InvalidAmount();
        gasBridge.config.maxDepositsPerDistribution = _maxDeposits;
    }

    // Token Bridge functions

    function _registerToken(
        address _neoXTokenAddress,
        StorageTypes.TokenType _tokenType,
        StorageTypes.TokenConfig memory _tokenConfig
    ) internal {
        // Check if token bridge is already registered
        if (_isRegisteredToken(_neoXTokenAddress))
            revert TokenBridgeAlreadyRegistered(_neoXTokenAddress);
        // Add token bridge to storage
        tokenBridges[_neoXTokenAddress] = StorageTypes.TokenBridge({
            locked: false,
            tokenType: _tokenType,
            depositState: StorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: StorageTypes.State({nonce: 0, root: 0x0}),
            config: _tokenConfig
        });
    }

    function _isRegisteredToken(
        address _neoXTokenAddress
    ) internal view returns (bool) {
        return
            tokenBridges[_neoXTokenAddress].config.neoN3TokenAddress !=
            address(0);
    }

    function _unregisterToken(address _neoXTokenAddress) internal {
        if (!_isRegisteredToken(_neoXTokenAddress))
            revert TokenBridgeNotRegistered(_neoXTokenAddress);
        delete tokenBridges[_neoXTokenAddress];
        // If a token is unregistered, the claimables remain in storage.
        // This means, that they are locked, and can only ever be retrieved again if there's a new token bridge registration with the same Neo X token address.
    }

    function _lockToken(address _neoXTokenAddress) internal {
        if ((!_isRegisteredToken(_neoXTokenAddress)))
            revert TokenBridgeNotRegistered(_neoXTokenAddress);
        tokenBridges[_neoXTokenAddress].locked = true;
    }

    function _unlockToken(address _neoXTokenAddress) internal {
        if ((!_isRegisteredToken(_neoXTokenAddress)))
            revert TokenBridgeNotRegistered(_neoXTokenAddress);
        tokenBridges[_neoXTokenAddress].locked = false;
    }

    function _setTokenMinWithdrawalAmount(
        address _neoXTokenAddress,
        uint256 _amount
    ) internal {
        if (_amount > tokenBridges[_neoXTokenAddress].config.maxAmount)
            revert InvalidAmount();
        tokenBridges[_neoXTokenAddress].config.minAmount = _amount;
    }

    function _setTokenMaxWithdrawalAmount(
        address _neoXTokenAddress,
        uint256 _amount
    ) internal {
        if (_amount < tokenBridges[_neoXTokenAddress].config.minAmount)
            revert InvalidAmount();
        tokenBridges[_neoXTokenAddress].config.maxAmount = _amount;
    }

    function _getTokenTypeConfig(
        StorageTypes.TokenType _tokenType
    ) internal view returns (StorageTypes.TokenTypeConfig memory) {
        return tokenTypeConfigs[_tokenType];
    }

    function _getNeoN3TokenAddress(
        address _neoXTokenAddress
    ) internal view returns (address) {
        return tokenBridges[_neoXTokenAddress].config.neoN3TokenAddress;
    }

    function _getWithdrawalFee(
        address _neoXTokenAddress
    ) internal view returns (uint256) {
        return tokenTypeConfigs[_getTokenType(_neoXTokenAddress)].fee;
    }

    function _setTokenTypeConfig(
        StorageTypes.TokenType _tokenType,
        StorageTypes.TokenTypeConfig memory _config
    ) internal {
        tokenTypeConfigs[_tokenType] = _config;
    }

    function _getTokenConfig(
        address _neoXTokenAddress
    ) internal view returns (StorageTypes.TokenConfig memory config) {
        return tokenBridges[_neoXTokenAddress].config;
    }

    function _getTokenType(
        address _neoXTokenAddress
    ) internal view returns (StorageTypes.TokenType) {
        return tokenBridges[_neoXTokenAddress].tokenType;
    }

    function _getTokenDepositState(
        address _neoXTokenAddress
    ) internal view returns (StorageTypes.State memory state) {
        return tokenBridges[_neoXTokenAddress].depositState;
    }

    function _setTokenDepositState(
        address _neoXTokenAddress,
        StorageTypes.State memory _state
    ) internal {
        assert(
            tokenBridges[_neoXTokenAddress].depositState.nonce < _state.nonce
        );
        tokenBridges[_neoXTokenAddress].depositState = _state;
    }

    function _getTokenWithdrawalState(
        address _neoXTokenAddress
    ) internal view returns (StorageTypes.State memory state) {
        return tokenBridges[_neoXTokenAddress].withdrawalState;
    }

    function _setTokenWithdrawalState(
        address _neoXTokenAddress,
        StorageTypes.State memory _state
    ) internal {
        assert(
            tokenBridges[_neoXTokenAddress].withdrawalState.nonce < _state.nonce
        );
        tokenBridges[_neoXTokenAddress].withdrawalState = _state;
    }

    function _getTokenClaimable(
        address _neoXTokenAddress,
        uint256 _nonce
    ) internal view returns (StorageTypes.Claimable memory) {
        return tokenClaimables[_neoXTokenAddress][_nonce];
    }

    function _addTokenClaimable(
        address _neoXTokenAddress,
        uint256 _nonce,
        uint256 _amount,
        address _to
    ) internal {
        tokenClaimables[_neoXTokenAddress][_nonce] = StorageTypes.Claimable({
            to: _to,
            amount: _amount
        });
    }

    function _deleteTokenClaimable(
        address _neoXTokenAddress,
        uint256 _nonce
    ) internal {
        delete tokenClaimables[_neoXTokenAddress][_nonce];
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

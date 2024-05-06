// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IBridgeManagement.sol";
import "../library/BridgeLib.sol";
import "../library/GasBridgeLib.sol";
import "../library/StorageTypes.sol";
import "../library/TokenBridgeLib.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BridgeStorage is UUPSUpgradeable, ReentrancyGuard {
    address public constant SELF = 0x1212100000000000000000000000000000000004;
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    // Begin Storage Slots

    // General Bridge Parameters
    IBridgeManagement public management;
    bool public locked;
    // Gas Bridge
    StorageTypes.GasBridge public gasBridge;
    mapping(uint256 => StorageTypes.Claimable) public claimableGas;
    // Token Bridges
    mapping(StorageTypes.TokenType tokenType => StorageTypes.TokenTypeConfig)
        public tokenTypeConfigs;
    // This mapping is intended for quick lookup of tokens by their address
    mapping(address tokenAddress => uint256 id) public tokenBridgeIds;
    mapping(uint256 id => StorageTypes.TokenBridge) public tokenBridges;
    mapping(uint256 id => mapping(uint256 nonce => StorageTypes.Claimable))
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
                gap: [uint256(0), uint256(0)]
            })
        });
    }

    error AddressAlreadyRegistered(address contractAddress);
    error InsufficientFee(uint256 provided, uint256 minExpected);
    error InvalidAddress();
    error InvalidAmount();
    error InvalidDepositsLength();
    error InvalidFee();
    error InvalidTokenId();
    error InvalidNonceSequence();
    error InvalidRoot();
    error InvalidValidatorSignatures();
    error NonexistentClaimable();
    error TokenAlreadyRegistered(uint256 id);
    error TokenIdNotRegistered(uint256 id);
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

    modifier unlocked() {
        require(!locked, "contract locked");
        _;
    }

    modifier tokenUnlocked(uint256 _id) {
        require(!tokenBridges[_id].locked, "token locked");
        _;
    }

    modifier tokenLocked(uint256 _id) {
        require(tokenBridges[_id].locked, "token unlocked");
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

    function _getTokenId(
        address _tokenAddress
    ) internal view returns (uint256) {
        uint256 _id = tokenBridgeIds[_tokenAddress];
        if (_id == 0) revert TokenIdNotRegistered(_id);
        return _id;
    }

    function _registerToken(
        uint256 _id,
        StorageTypes.TokenType _tokenType,
        StorageTypes.TokenConfig memory _tokenConfig
    ) internal {
        if (_id == 0) revert InvalidTokenId();
        // Check if token config contains valid values
        if (_tokenConfig.minAmount > _tokenConfig.maxAmount)
            revert InvalidAmount();
        if (_tokenConfig.contractAddress == address(0)) revert InvalidAddress();

        // Check if token bridge is already registered
        if (_isRegisteredToken(_id)) revert TokenAlreadyRegistered(_id);
        if (_isRegisteredToken(_tokenConfig.contractAddress))
            revert AddressAlreadyRegistered(_tokenConfig.contractAddress);
        // Map token address to identifier
        tokenBridgeIds[_tokenConfig.contractAddress] = _id;
        // Add token bridge to storage
        tokenBridges[_id] = StorageTypes.TokenBridge({
            locked: false,
            tokenType: _tokenType,
            depositState: StorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: StorageTypes.State({nonce: 0, root: 0x0}),
            config: _tokenConfig
        });
    }

    function _isRegisteredToken(uint256 _id) internal view returns (bool) {
        return tokenBridges[_id].config.contractAddress != address(0);
    }

    function _isRegisteredToken(
        address _contractAddress
    ) internal view returns (bool) {
        return tokenBridgeIds[_contractAddress] != 0;
    }

    function _isRegisteredToken(
        StorageTypes.TokenBridge storage tokenBridge
    ) internal view returns (bool) {
        return tokenBridge.config.contractAddress != address(0);
    }

    function _unregisterToken(uint256 _id) internal {
        if (!_isRegisteredToken(tokenBridges[_id]))
            revert TokenIdNotRegistered(_id);
        // By choice the tokenBridgeIds entry is not deleted in order to restrict from re-registering an identifier.
        // Re-registering an identifier could open up to replay attack vectors since signatures are publicly known for previous bridge operations.
        delete tokenBridges[_id];
    }

    function _lockToken(uint256 _id) internal {
        if ((!_isRegisteredToken(tokenBridges[_id])))
            revert TokenIdNotRegistered(_id);
        tokenBridges[_id].locked = true;
    }

    function _unlockToken(uint256 _id) internal {
        if ((!_isRegisteredToken(tokenBridges[_id])))
            revert TokenIdNotRegistered(_id);
        tokenBridges[_id].locked = false;
    }

    function _setTokenMinWithdrawalAmount(
        uint256 _id,
        uint256 _amount
    ) internal {
        if (_amount > tokenBridges[_id].config.maxAmount)
            revert InvalidAmount();
        tokenBridges[_id].config.minAmount = _amount;
    }

    function _setTokenMaxWithdrawalAmount(
        uint256 _id,
        uint256 _amount
    ) internal {
        if (_amount < tokenBridges[_id].config.minAmount)
            revert InvalidAmount();
        tokenBridges[_id].config.maxAmount = _amount;
    }

    function _getTokenTypeConfig(
        StorageTypes.TokenType _tokenType
    ) internal view returns (StorageTypes.TokenTypeConfig memory) {
        return tokenTypeConfigs[_tokenType];
    }

    function _getWithdrawalFee(uint256 _id) internal view returns (uint256) {
        return tokenTypeConfigs[_getTokenType(_id)].fee;
    }

    function _setTokenTypeConfig(
        StorageTypes.TokenType _tokenType,
        StorageTypes.TokenTypeConfig memory _config
    ) internal {
        tokenTypeConfigs[_tokenType] = _config;
    }

    function _getTokenConfig(
        uint256 _id
    ) internal view returns (StorageTypes.TokenConfig memory config) {
        return tokenBridges[_id].config;
    }

    function _getTokenType(
        uint256 _id
    ) internal view returns (StorageTypes.TokenType) {
        return tokenBridges[_id].tokenType;
    }

    function _getTokenDepositState(
        uint256 _id
    ) internal view returns (StorageTypes.State memory state) {
        return tokenBridges[_id].depositState;
    }

    function _setTokenDepositState(
        uint256 _id,
        StorageTypes.State memory _state
    ) internal {
        assert(tokenBridges[_id].depositState.nonce < _state.nonce);
        tokenBridges[_id].depositState = _state;
    }

    function _getTokenWithdrawalState(
        uint256 _id
    ) internal view returns (StorageTypes.State memory state) {
        return tokenBridges[_id].withdrawalState;
    }

    function _setTokenWithdrawalState(
        uint256 _id,
        StorageTypes.State memory _state
    ) internal {
        assert(tokenBridges[_id].withdrawalState.nonce < _state.nonce);
        tokenBridges[_id].withdrawalState = _state;
    }

    function _getTokenClaimable(
        uint256 _id,
        uint256 _nonce
    ) internal view returns (StorageTypes.Claimable memory) {
        return tokenClaimables[_id][_nonce];
    }

    function _addTokenClaimable(
        uint256 _id,
        uint256 _nonce,
        uint256 _amount,
        address _to
    ) internal {
        tokenClaimables[_id][_nonce] = StorageTypes.Claimable({
            to: _to,
            amount: _amount
        });
    }

    function _deleteTokenClaimable(uint256 _id, uint256 _nonce) internal {
        delete tokenClaimables[_id][_nonce];
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

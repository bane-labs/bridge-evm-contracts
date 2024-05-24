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
    bool public bridgePaused;
    // Gas Bridge
    StorageTypes.GasBridge public gasBridge;
    mapping(uint256 nonce => StorageTypes.Claimable claimable)
        public claimableGas;
    // Unclaimed Fee Rewards
    uint256 public unclaimedRewards;
    // Token Bridges
    mapping(address tokenAddress => StorageTypes.TokenBridge tokenBridge)
        public tokenBridges;
    mapping(address tokenAddress => mapping(uint256 nonce => StorageTypes.Claimable claimable) claimableTokens)
        public tokenClaimables;

    // End Storage Slots

    constructor(address _management) {
        _disableInitializers();
        management = IBridgeManagement(_management);
        gasBridge = StorageTypes.GasBridge({
            depositState: StorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: StorageTypes.State({nonce: 0, root: 0x0}),
            config: StorageTypes.GasConfig({
                fee: 1e17,
                minAmount: 1e18,
                maxAmount: 1e22,
                maxDeposits: 100,
                paused: false,
                gap: [uint256(0), uint256(0)]
            })
        });
    }

    error BridgePaused();
    error BridgeUnpaused();
    error GasBridgePaused();
    error GasBridgeUnpaused();
    error InsufficientFee(uint256 provided, uint256 minExpected);
    error InvalidAddress();
    error InvalidAmount();
    error InvalidDepositsLength();
    error InvalidFee();
    error InvalidTokenAddress();
    error InvalidTokenConfig();
    error InvalidNonceSequence();
    error InvalidRoot();
    error InvalidValidatorSignatures();
    error LengthMismatch();
    error NonexistentClaimable();
    error TokenBridgeAlreadyRegistered(address neoXToken);
    error TokenBridgePaused(address neoXToken);
    error TokenBridgeUnpaused(address neoXToken);
    error TokenBridgeNotRegistered(address neoXToken);
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

    modifier onlyBridgeUnpaused() {
        if (bridgePaused) revert BridgePaused();
        _;
    }

    modifier onlyBridgePaused() {
        if (!bridgePaused) revert BridgeUnpaused();
        _;
    }

    modifier onlyGasBridgeUnpaused() {
        if (gasBridge.config.paused) revert GasBridgePaused();
        _;
    }

    modifier onlyGasBridgePaused() {
        if (!gasBridge.config.paused) revert GasBridgeUnpaused();
        _;
    }

    modifier onlyTokenBridgeUnpaused(address _neoXToken) {
        if (tokenBridges[_neoXToken].paused)
            revert TokenBridgePaused(_neoXToken);
        _;
    }

    modifier onlyTokenBridgePaused(address _neoXToken) {
        if (!tokenBridges[_neoXToken].paused)
            revert TokenBridgeUnpaused(_neoXToken);
        _;
    }

    // Pause Bridge functions

    function _pauseBridge() internal {
        bridgePaused = true;
    }

    function _unpauseBridge() internal {
        bridgePaused = false;
    }

    // Unclaimed Rewards functions

    function _addUnclaimedRewards(uint256 _amount) internal {
        unclaimedRewards += _amount;
    }

    // Gas Bridge functions

    function _pauseGasBridge() internal {
        gasBridge.config.paused = true;
    }

    function _unpauseGasBridge() internal {
        gasBridge.config.paused = false;
    }

    function _addClaimableGas(
        uint256 _nonce,
        address _to,
        uint256 _amount
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

    function _setMaxGasDeposits(uint8 _maxDeposits) internal {
        if (_maxDeposits == 0) revert InvalidAmount();
        gasBridge.config.maxDeposits = _maxDeposits;
    }

    // Token Bridge functions

    function _registerToken(
        address _neoXToken,
        StorageTypes.TokenConfig memory _tokenConfig
    ) internal {
        // Check if token bridge is already registered
        if (_isRegisteredToken(_neoXToken))
            revert TokenBridgeAlreadyRegistered(_neoXToken);
        if (TokenBridgeLib._isValidConfig(_tokenConfig))
            revert InvalidTokenConfig();

        // Add token bridge to storage
        tokenBridges[_neoXToken] = StorageTypes.TokenBridge({
            paused: false,
            depositState: StorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: StorageTypes.State({nonce: 0, root: 0x0}),
            config: _tokenConfig
        });
    }

    function _isRegisteredToken(
        address _neoXToken
    ) internal view returns (bool) {
        return tokenBridges[_neoXToken].config.neoN3Token != address(0);
    }

    function _unregisterToken(address _neoXToken) internal {
        if (!_isRegisteredToken(_neoXToken))
            revert TokenBridgeNotRegistered(_neoXToken);
        delete tokenBridges[_neoXToken];
        // If a token is unregistered, the claimables remain in storage.
        // This means, that they are locked, and can only ever be retrieved again if there's a new token bridge registration with the same Neo X token address.
    }

    function _pauseToken(address _neoXToken) internal {
        if ((!_isRegisteredToken(_neoXToken)))
            revert TokenBridgeNotRegistered(_neoXToken);
        tokenBridges[_neoXToken].paused = true;
    }

    function _unpauseToken(address _neoXToken) internal {
        if ((!_isRegisteredToken(_neoXToken)))
            revert TokenBridgeNotRegistered(_neoXToken);
        tokenBridges[_neoXToken].paused = false;
    }

    function _setTokenWithdrawalFee(address _neoXToken, uint256 _fee) internal {
        tokenBridges[_neoXToken].config.fee = _fee;
    }

    function _setTokenMinWithdrawalAmount(
        address _neoXToken,
        uint256 _amount
    ) internal {
        if (_amount > tokenBridges[_neoXToken].config.maxAmount)
            revert InvalidAmount();
        tokenBridges[_neoXToken].config.minAmount = _amount;
    }

    function _setTokenMaxWithdrawalAmount(
        address _neoXToken,
        uint256 _amount
    ) internal {
        if (_amount < tokenBridges[_neoXToken].config.minAmount)
            revert InvalidAmount();
        tokenBridges[_neoXToken].config.maxAmount = _amount;
    }

    function _setMaxTokenDeposits(
        address _neoXToken,
        uint256 _maxDeposits
    ) internal {
        tokenBridges[_neoXToken].config.maxDeposits = _maxDeposits;
    }

    function _getNeoN3Token(
        address _neoXToken
    ) internal view returns (address) {
        return tokenBridges[_neoXToken].config.neoN3Token;
    }

    function _getTokenConfig(
        address _neoXToken
    ) internal view returns (StorageTypes.TokenConfig memory config) {
        return tokenBridges[_neoXToken].config;
    }

    function _getTokenType(
        address _neoXToken
    ) internal view returns (StorageTypes.TokenType) {
        return tokenBridges[_neoXToken].config.tokenType;
    }

    function _getTokenDepositState(
        address _neoXToken
    ) internal view returns (StorageTypes.State memory state) {
        return tokenBridges[_neoXToken].depositState;
    }

    function _setTokenDepositState(
        address _neoXToken,
        StorageTypes.State memory _state
    ) internal {
        assert(tokenBridges[_neoXToken].depositState.nonce < _state.nonce);
        tokenBridges[_neoXToken].depositState = _state;
    }

    function _getTokenWithdrawalState(
        address _neoXToken
    ) internal view returns (StorageTypes.State memory state) {
        return tokenBridges[_neoXToken].withdrawalState;
    }

    function _setTokenWithdrawalState(
        address _neoXToken,
        StorageTypes.State memory _state
    ) internal {
        assert(tokenBridges[_neoXToken].withdrawalState.nonce < _state.nonce);
        tokenBridges[_neoXToken].withdrawalState = _state;
    }

    function _getTokenClaimable(
        address _neoXToken,
        uint256 _nonce
    ) internal view returns (StorageTypes.Claimable memory) {
        return tokenClaimables[_neoXToken][_nonce];
    }

    function _addTokenClaimable(
        address _neoXToken,
        uint256 _nonce,
        address _to,
        uint256 _amount
    ) internal {
        tokenClaimables[_neoXToken][_nonce] = StorageTypes.Claimable({
            to: _to,
            amount: _amount
        });
    }

    function _deleteTokenClaimable(
        address _neoXToken,
        uint256 _nonce
    ) internal {
        delete tokenClaimables[_neoXToken][_nonce];
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

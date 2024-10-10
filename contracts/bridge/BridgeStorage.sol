// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../interfaces/IBridgeManagement.sol";
import "../library/BridgeLib.sol";
import "../library/GasBridgeLib.sol";
import "../library/StorageTypes.sol";
import "../library/TokenBridgeLib.sol";
import "./BridgeStorageV1.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @dev This contract holds errors, modifiers, internal view functions and functions that directly modify the storage. The modification functions have logical checks but no access-checks. For example, registering a token should only be viable if there is no entry for that token already. However, checking if the msg.sender is allowed to do so should be handled in a higher-level contract (i.e., in this case the corresponding Impl contract).
 */
abstract contract BridgeStorage is BridgeStorageV1, UUPSUpgradeable {
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    error AmountBelowMinAmount(uint256 minAmount, uint256 provided);
    error AmountExceedsMaxAmount(uint256 maxAmount, uint256 provided);
    error BridgePaused();
    error BridgeNotPaused();
    error ExactFeeRequired(uint256 feeExpected, uint256 feeProvided);
    error GasBridgePaused();
    error GasBridgeNotPaused();
    error InsufficientFee(uint256 minExpected, uint256 provided);
    error InvalidAddress();
    error InvalidAmount();
    error InvalidDepositsLength();
    error InvalidFee();
    error InvalidTokenAddress();
    error InvalidTokenConfig();
    error InvalidTransfer();
    error InvalidNonceSequence();
    error InvalidRoot();
    error InvalidValidatorSignatures();
    error InvalidValue();
    error LengthMismatch();
    error MaxFeeExceeded(uint256 maxFeeAllowed, uint256 actualFee);
    error NoAuthorization();
    error NonexistentClaimable();
    error TokenBridgeAlreadyRegistered(address neoXToken);
    error TokenBridgePaused(address neoXToken);
    error TokenBridgeNotPaused(address neoXToken);
    error TokenBridgeNotRegistered(address neoXToken);
    error TransferFailed();
    error WithdrawalsPaused();
    error WithdrawalsNotPaused();

    // Modifiers for Role Restriction

    modifier onlyRelayer() {
        require(msg.sender == management.getRelayer(), "not relayer");
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == management.getGovernor(), "not governor");
        _;
    }

    modifier onlyGovernorOrSecurityGuard() {
        if (
            msg.sender != management.getGovernor() &&
            msg.sender != management.getSecurityGuard()
        ) revert NoAuthorization();
        _;
    }

    modifier onlyFunder() {
        require(msg.sender == management.getFunder(), "not funder");
        _;
    }

    modifier whenBridgeNotPaused() {
        if (bridgePaused) revert BridgePaused();
        _;
    }

    modifier whenBridgePaused() {
        if (!bridgePaused) revert BridgeNotPaused();
        _;
    }

    modifier whenWithdrawalsPaused() {
        if (!withdrawalsPaused) revert WithdrawalsNotPaused();
        _;
    }

    modifier whenWithdrawalsNotPaused() {
        if (withdrawalsPaused) revert WithdrawalsPaused();
        _;
    }

    modifier whenGasBridgeNotPaused() {
        if (gasBridge.paused) revert GasBridgePaused();
        _;
    }

    modifier whenGasBridgePaused() {
        if (!gasBridge.paused) revert GasBridgeNotPaused();
        _;
    }

    modifier onlyIfTokenRegistered(address _neoXToken) {
        if (!_isRegisteredToken(_neoXToken))
            revert TokenBridgeNotRegistered(_neoXToken);
        _;
    }

    modifier whenTokenBridgeNotPaused(address _neoXToken) {
        if (tokenBridges[_neoXToken].paused)
            revert TokenBridgePaused(_neoXToken);
        _;
    }

    modifier whenTokenBridgePaused(address _neoXToken) {
        if (!tokenBridges[_neoXToken].paused)
            revert TokenBridgeNotPaused(_neoXToken);
        _;
    }

    // Pause Bridge functions

    function _pauseBridge() internal {
        bridgePaused = true;
    }

    function _unpauseBridge() internal {
        bridgePaused = false;
    }

    function _pauseWithdrawals() internal {
        withdrawalsPaused = true;
    }

    function _unpauseWithdrawals() internal {
        withdrawalsPaused = false;
    }

    // Unclaimed Rewards functions

    function _addUnclaimedRewards(uint256 _amount) internal {
        unclaimedRewards += _amount;
    }

    // Gas Bridge functions

    function _pauseGasBridge() internal {
        gasBridge.paused = true;
    }

    function _unpauseGasBridge() internal {
        gasBridge.paused = false;
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
        if (_fee == 0) revert InvalidFee();
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

    function _setMaxGasDeposits(uint256 _maxDeposits) internal {
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

    function _pauseToken(address _neoXToken) internal {
        tokenBridges[_neoXToken].paused = true;
    }

    function _unpauseToken(address _neoXToken) internal {
        tokenBridges[_neoXToken].paused = false;
    }

    function _setTokenWithdrawalFee(
        address _neoXToken,
        uint256 _fee
    ) internal onlyIfTokenRegistered(_neoXToken) {
        if (_fee == 0) revert InvalidFee();
        tokenBridges[_neoXToken].config.fee = _fee;
    }

    function _setTokenMinWithdrawalAmount(
        address _neoXToken,
        uint256 _amount
    ) internal onlyIfTokenRegistered(_neoXToken) {
        if (_amount >= tokenBridges[_neoXToken].config.maxAmount)
            revert InvalidAmount();
        tokenBridges[_neoXToken].config.minAmount = _amount;
    }

    function _setTokenMaxWithdrawalAmount(
        address _neoXToken,
        uint256 _amount
    ) internal onlyIfTokenRegistered(_neoXToken) {
        if (_amount <= tokenBridges[_neoXToken].config.minAmount)
            revert InvalidAmount();
        tokenBridges[_neoXToken].config.maxAmount = _amount;
    }

    function _setMaxTokenDeposits(
        address _neoXToken,
        uint256 _maxDeposits
    ) internal onlyIfTokenRegistered(_neoXToken) {
        if (_maxDeposits == 0) revert InvalidValue();
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
}

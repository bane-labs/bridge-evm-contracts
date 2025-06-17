// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IBridgeManagement.sol";
import "../library/BridgeLib.sol";
import "../library/StorageTypes.sol";
import "../library/NativeBridgeLib.sol";
import "../library/TokenBridgeLib.sol";
import "./BridgeStorageV1.sol";

/**
 * @dev This contract holds errors, modifiers, internal view functions and functions that directly modify the storage. The modification functions have logical checks but no access-checks. For example, registering a token should only be viable if there is no entry for that token already. However, checking if the msg.sender is allowed to do so should be handled in a higher-level contract (i.e., in this case the corresponding Impl contract).
 */
abstract contract BridgeStorage is BridgeStorageV1, UUPSUpgradeable {
    address public constant GOV_ADMIN = 0x1212000000000000000000000000000000000000;

    //0x626ade30
    error ValueMismatch(uint256 expected, uint256 received);
    //0x944c2c78
    error MessageAlreadyExists(uint256 nonce);
    //0x03290dc9
    error MessageNotFound(uint256 nonce);
    //0xa5fa8d2b
    error CallFailed(bytes reason);
    //0xf6a1af31
    error AmountBelowMinAmount(uint256 minAmount, uint256 provided);
    //0x030e0197
    error AmountExceedsMaxAmount(uint256 maxAmount, uint256 provided);
    //0xa792dfa3
    error BridgePaused();
    //0x733169a2
    error BridgeNotPaused();
    //0x038d5f7b
    error ExactFeeRequired(uint256 feeExpected, uint256 feeProvided);
    //0x3988a48c
    error NativeBridgePaused();
    //0x00bb2a95
    error NativeBridgeNotPaused();
    //0xa458261b
    error InsufficientFee(uint256 minExpected, uint256 provided);
    //0xe6c4247b
    error InvalidAddress();
    //0x2c5211c6
    error InvalidAmount();
    //0xe7795849
    error InvalidDepositsLength();
    //0x58d620b3
    error InvalidFee();
    //0x1eb00b06
    error InvalidTokenAddress();
    //0x07fe7bae
    error InvalidTokenConfig();
    //0x2f352531
    error InvalidTransfer();
    //0xd7c2b571
    error InvalidNonceSequence();
    //0x504570e3
    error InvalidRoot();
    //0xc48c8e48
    error InvalidValidatorSignatures();
    //0xaa7feadc
    error InvalidValue();
    //0xff633a38
    error LengthMismatch();
    //0xa85293eb
    error MaxFeeExceeded(uint256 maxFeeAllowed, uint256 actualFee);
    //0x5df7f28a
    error NativeBridgeAlreadySet();
    //0x2e56a1ef
    error NativeBridgeNotSet();
    //0x79828e03
    error NoAuthorization();
    //0x475a97bd
    error NonexistentClaimable();
    //0x156f3496
    error TokenBridgeAlreadyRegistered(address neoXToken);
    //0xa913676a
    error TokenBridgePaused(address neoXToken);
    //0x817bff80
    error TokenBridgeNotPaused(address neoXToken);
    //0x32febabe
    error TokenBridgeNotRegistered(address neoXToken);
    //0x90b8ec18
    error TransferFailed();
    //0x6022a9e7
    error WithdrawalsPaused();
    //0x65b32663
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
        if (msg.sender != management.getGovernor() && msg.sender != management.getSecurityGuard()) {
            revert NoAuthorization();
        }
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

    modifier onlyIfNativeBridgeSet() {
        if (!_nativeBridgeIsSet()) revert NativeBridgeNotSet();
        _;
    }

    modifier onlyIfNativeBridgeNotSet() {
        if (_nativeBridgeIsSet()) revert NativeBridgeAlreadySet();
        _;
    }

    modifier whenNativeBridgeNotPaused() {
        if (nativeBridge.paused) revert NativeBridgePaused();
        _;
    }

    modifier whenNativeBridgePaused() {
        if (!nativeBridge.paused) revert NativeBridgeNotPaused();
        _;
    }

    modifier onlyIfTokenRegistered(address _neoXToken) {
        if (!_isRegisteredToken(_neoXToken)) revert TokenBridgeNotRegistered(_neoXToken);
        _;
    }

    modifier whenTokenBridgeNotPaused(address _neoXToken) {
        if (tokenBridges[_neoXToken].paused) revert TokenBridgePaused(_neoXToken);
        _;
    }

    modifier whenTokenBridgePaused(address _neoXToken) {
        if (!tokenBridges[_neoXToken].paused) revert TokenBridgeNotPaused(_neoXToken);
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

    // Native Coin Bridge functions

    function _nativeBridgeIsSet() internal view returns (bool) {
        return nativeBridge.config.maxAmount != 0;
    }

    function _setNativeBridge(
        uint256 _fee,
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _maxDeposits,
        uint256 _decimalsHere,
        uint256 _decimalsOnN3
    )
        internal
    {
        if (_fee == 0) revert InvalidFee();
        if (_maxAmount == 0 || _minAmount >= _maxAmount) revert InvalidAmount();
        if (_maxDeposits == 0) revert InvalidValue();
        if (_decimalsHere > 36 || _decimalsOnN3 > 36) revert InvalidValue();

        uint256 decimalScalingFactor = 0;
        if (_decimalsHere > _decimalsOnN3) decimalScalingFactor = _decimalsHere - _decimalsOnN3;
        nativeBridge = StorageTypes.NativeBridgeV3({
            paused: true,
            depositState: StorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: StorageTypes.State({nonce: 0, root: 0x0}),
            config: StorageTypes.NativeConfigV3({
                fee: _fee,
                minAmount: _minAmount,
                maxAmount: _maxAmount,
                maxDeposits: _maxDeposits,
                decimalScalingFactor: decimalScalingFactor
            })
        });
    }

    function _pauseNativeBridge() internal {
        nativeBridge.paused = true;
    }

    function _unpauseNativeBridge() internal {
        nativeBridge.paused = false;
    }

    function _addClaimableNative(uint256 _nonce, address _to, uint256 _amount) internal {
        claimableNative[_nonce] = StorageTypes.Claimable({to: _to, amount: _amount});
    }

    function _getNativeClaimable(uint256 _nonce) internal view returns (StorageTypes.Claimable memory) {
        return claimableNative[_nonce];
    }

    function _deleteNativeClaimable(uint256 _nonce) internal {
        delete claimableNative[_nonce];
    }

    function _getNativeBridgeConfig() internal view returns (StorageTypes.NativeConfigV3 memory config) {
        return nativeBridge.config;
    }

    function _getNativeBridgeDepositState() internal view returns (StorageTypes.State memory state) {
        return nativeBridge.depositState;
    }

    function _setNativeBridgeDepositState(StorageTypes.State memory state) internal {
        nativeBridge.depositState = state;
    }

    function _getNativeBridgeWithdrawalState() internal view returns (StorageTypes.State memory state) {
        return nativeBridge.withdrawalState;
    }

    function _setNativeBridgeWithdrawalState(StorageTypes.State memory state) internal {
        nativeBridge.withdrawalState = state;
    }

    function _setNativeWithdrawalFee(uint256 _fee) internal {
        if (_fee == 0) revert InvalidFee();
        if ((_fee % (10 ** nativeBridge.config.decimalScalingFactor)) != 0) revert InvalidFee();
        nativeBridge.config.fee = _fee;
    }

    function _setNativeWithdrawalMinAmount(uint256 _amount) internal {
        if ((_amount % (10 ** nativeBridge.config.decimalScalingFactor)) != 0) revert InvalidAmount();
        if (_amount >= nativeBridge.config.maxAmount) revert InvalidAmount();
        nativeBridge.config.minAmount = _amount;
    }

    function _setNativeWithdrawalMaxAmount(uint256 _amount) internal {
        if ((_amount % (10 ** nativeBridge.config.decimalScalingFactor)) != 0) revert InvalidAmount();
        if (_amount == 0 || _amount <= nativeBridge.config.minAmount) revert InvalidAmount();
        nativeBridge.config.maxAmount = _amount;
    }

    function _setMaxNativeDeposits(uint256 _maxDeposits) internal {
        if (_maxDeposits == 0) revert InvalidAmount();
        nativeBridge.config.maxDeposits = _maxDeposits;
    }

    // Token Bridge functions

    function _registerToken(address _neoXToken, StorageTypes.TokenConfig memory _tokenConfig) internal {
        // Check if token bridge is already registered
        if (_isRegisteredToken(_neoXToken)) revert TokenBridgeAlreadyRegistered(_neoXToken);

        // Add token bridge to storage
        tokenBridges[_neoXToken] = StorageTypes.TokenBridge({
            paused: true,
            depositState: StorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: StorageTypes.State({nonce: 0, root: 0x0}),
            config: _tokenConfig
        });
        registeredTokens.push(_neoXToken);
    }

    function _isRegisteredToken(address _neoXToken) internal view returns (bool) {
        return tokenBridges[_neoXToken].config.neoN3Token != address(0);
    }

    function _pauseToken(address _neoXToken) internal {
        tokenBridges[_neoXToken].paused = true;
    }

    function _unpauseToken(address _neoXToken) internal {
        tokenBridges[_neoXToken].paused = false;
    }

    function _setTokenWithdrawalFee(address _neoXToken, uint256 _fee) internal onlyIfTokenRegistered(_neoXToken) {
        if (_fee == 0) revert InvalidFee();
        tokenBridges[_neoXToken].config.fee = _fee;
    }

    function _setTokenMinWithdrawalAmount(
        address _neoXToken,
        uint256 _amount
    )
        internal
        onlyIfTokenRegistered(_neoXToken)
    {
        if (_amount >= tokenBridges[_neoXToken].config.maxAmount) revert InvalidAmount();
        tokenBridges[_neoXToken].config.minAmount = _amount;
    }

    function _setTokenMaxWithdrawalAmount(
        address _neoXToken,
        uint256 _amount
    )
        internal
        onlyIfTokenRegistered(_neoXToken)
    {
        if (_amount <= tokenBridges[_neoXToken].config.minAmount) revert InvalidAmount();
        tokenBridges[_neoXToken].config.maxAmount = _amount;
    }

    function _setMaxTokenDeposits(
        address _neoXToken,
        uint256 _maxDeposits
    )
        internal
        onlyIfTokenRegistered(_neoXToken)
    {
        if (_maxDeposits == 0) revert InvalidValue();
        tokenBridges[_neoXToken].config.maxDeposits = _maxDeposits;
    }

    function _getNeoN3Token(address _neoXToken) internal view returns (address) {
        return tokenBridges[_neoXToken].config.neoN3Token;
    }

    function _getTokenConfig(address _neoXToken) internal view returns (StorageTypes.TokenConfig memory config) {
        return tokenBridges[_neoXToken].config;
    }

    function _getTokenDepositState(address _neoXToken) internal view returns (StorageTypes.State memory state) {
        return tokenBridges[_neoXToken].depositState;
    }

    function _setTokenDepositState(address _neoXToken, StorageTypes.State memory _state) internal {
        assert(tokenBridges[_neoXToken].depositState.nonce < _state.nonce);
        tokenBridges[_neoXToken].depositState = _state;
    }

    function _getTokenWithdrawalState(address _neoXToken) internal view returns (StorageTypes.State memory state) {
        return tokenBridges[_neoXToken].withdrawalState;
    }

    function _setTokenWithdrawalState(address _neoXToken, StorageTypes.State memory _state) internal {
        assert(tokenBridges[_neoXToken].withdrawalState.nonce < _state.nonce);
        tokenBridges[_neoXToken].withdrawalState = _state;
    }

    function _getTokenClaimable(
        address _neoXToken,
        uint256 _nonce
    )
        internal
        view
        returns (StorageTypes.Claimable memory)
    {
        return tokenClaimables[_neoXToken][_nonce];
    }

    function _addTokenClaimable(address _neoXToken, uint256 _nonce, address _to, uint256 _amount) internal {
        tokenClaimables[_neoXToken][_nonce] = StorageTypes.Claimable({to: _to, amount: _amount});
    }

    function _deleteTokenClaimable(address _neoXToken, uint256 _nonce) internal {
        delete tokenClaimables[_neoXToken][_nonce];
    }

    // Upgrade authorization

    modifier onlyAdmin() {
        require(msg.sender == GOV_ADMIN, "not admin");
        _;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyAdmin {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../management/BridgeManagementImpl.sol";
import "../library/BridgeLib.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BridgeStorage is UUPSUpgradeable {
    address public constant SELF = 0x1212100000000000000000000000000000000004;
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    // Begin Storage Slots
    IBridgeManagement public management =
        IBridgeManagement(0xF1478f211F027EBA42ca369ea976F1eB43C6bB53);
    bool public locked;
    BridgeLib.GasBridge public gasBridge =
        BridgeLib.GasBridge({
            depositState: BridgeLib.State({nonce: 0, root: 0x0}),
            withdrawalState: BridgeLib.State({nonce: 0, root: 0x0}),
            config: BridgeLib.GasConfig({
                fee: 10 ** 17,
                minAmount: 10 ** 18,
                maxAmount: 10 ** 22,
                maxDepositsPerDistribution: 100,
                gap: [uint256(0), uint256(0)]
            })
        });
    mapping(uint64 => BridgeLib.Claimable) public claimableGas;
    // End Storage Slots

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

    function _lock() internal {
        require(!locked, "already locked");
        locked = true;
    }

    function _unlock() internal {
        require(locked, "already unlocked");
        locked = false;
    }

    function _addClaimableGas(
        uint64 _nonce,
        uint64 _amount,
        address _to
    ) internal {
        claimableGas[_nonce] = BridgeLib.Claimable({to: _to, amount: _amount});
    }

    function _getGasClaimable(
        uint64 _nonce
    ) internal view returns (BridgeLib.Claimable memory) {
        return claimableGas[_nonce];
    }

    function _deleteGasClaimable(uint64 _nonce) internal {
        delete claimableGas[_nonce];
    }

    function _getGasBridgeConfig()
        internal
        view
        returns (BridgeLib.GasConfig memory config)
    {
        return gasBridge.config;
    }

    function _getGasBridgeDepositState()
        internal
        view
        returns (BridgeLib.State memory state)
    {
        return gasBridge.depositState;
    }

    function _setGasBridgeDepositState(BridgeLib.State memory state) internal {
        gasBridge.depositState = state;
    }

    function _getGasBridgeWithdrawalState()
        internal
        view
        returns (BridgeLib.State memory state)
    {
        return gasBridge.withdrawalState;
    }

    function _setGasBridgeWithdrawalState(
        BridgeLib.State memory state
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

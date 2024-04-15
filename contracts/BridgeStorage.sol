// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgeManagementImpl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BridgeStorage is UUPSUpgradeable {
    address public constant SELF = 0x1212100000000000000000000000000000000004;
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    IBridgeManagement public management =
        IBridgeManagement(0x72bb9c7ffbE2Ed234e53bc64862DdA6d9fFF333b);
    GasBridge public gasBridge =
        GasBridge({
            depositState: State({nonce: 0, root: 0x0}),
            withdrawalState: State({nonce: 0, root: 0x0}),
            config: Config({
                fee: 10 ** 17,
                minAmount: 10 ** 18,
                maxAmount: 10 ** 22,
                maxDepositsPerDistribution: 100,
                gap: [uint256(0), uint256(0)]
            })
        });
    mapping(uint64 => GasClaimable) public claimableGas;
    bool public locked;

    struct GasBridge {
        State depositState;
        State withdrawalState;
        Config config;
    }

    struct State {
        uint64 nonce;
        bytes32 root;
    }

    struct Config {
        uint256 fee;
        uint256 minAmount;
        uint256 maxAmount;
        uint8 maxDepositsPerDistribution;
        uint256[2] gap;
    }

    struct GasClaimable {
        address to;
        uint64 amount;
    }

    // Modifiers for Role Restriction

    modifier onlyRelayer() {
        require(msg.sender == management.getRelayer(), "Not relayer");
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == management.getGovernor(), "Not governor");
        _;
    }

    modifier onlySecurityGuard() {
        require(
            msg.sender == management.getSecurityGuard(),
            "Not securityGuard"
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == management.getOwner(), "Not owner");
        _;
    }

    modifier unlocked() {
        require(!locked, "Contract is locked");
        _;
    }

    function _lock() internal {
        require(!locked, "Contract is already locked.");
        locked = true;
    }

    function _unlock() internal {
        require(locked, "Contract is already unlocked.");
        locked = false;
    }

    function _addClaimableGas(
        uint64 _nonce,
        uint64 _amount,
        address _to
    ) internal {
        claimableGas[_nonce] = GasClaimable({to: _to, amount: _amount});
    }

    function _getGasClaimable(
        uint64 _nonce
    ) internal view returns (GasClaimable memory) {
        return claimableGas[_nonce];
    }

    function _deleteGasClaimable(uint64 _nonce) internal {
        delete claimableGas[_nonce];
    }

    function _getGasBridgeConfig()
        internal
        view
        returns (Config memory config)
    {
        return gasBridge.config;
    }

    function _getGasBridgeDepositState()
        internal
        view
        returns (State memory state)
    {
        return gasBridge.depositState;
    }

    function _setGasBridgeDepositState(State memory state) internal {
        gasBridge.depositState = state;
    }

    function _getGasBridgeWithdrawalState()
        internal
        view
        returns (State memory state)
    {
        return gasBridge.withdrawalState;
    }

    function _setGasBridgeWithdrawalState(State memory state) internal {
        gasBridge.withdrawalState = state;
    }

    function _setGasWithdrawalFee(uint256 _fee) internal {
        require(
            (_fee % (10 ** 10)) == 0,
            "Fee must have maximally 8 non-zero decimals"
        );
        gasBridge.config.fee = _fee;
    }

    function _setGasWithdrawalMinAmount(uint256 _amount) internal {
        require(
            (_amount % (10 ** 10)) == 0,
            "Amount must have maximally 8 non-zero decimals"
        );
        require(
            _amount < gasBridge.config.maxAmount,
            "Amount must be less than the maximal withdrawal amount"
        );
        gasBridge.config.minAmount = _amount;
    }

    function _setGasWithdrawalMaxAmount(uint256 _amount) internal {
        require(
            (_amount % (10 ** 10)) == 0,
            "Amount must have maximally 8 non-zero decimals"
        );
        require(
            _amount > gasBridge.config.minAmount,
            "Amount must be greater than the minimal withdrawal amount"
        );
        gasBridge.config.maxAmount = _amount;
    }

    function _setGasMaxNrDepositsPerDistribution(uint8 _maxDeposits) internal {
        require(_maxDeposits > 0, "Value must be greater than 0");
        gasBridge.config.maxDepositsPerDistribution = _maxDeposits;
    }

    // Upgrade authorization

    modifier onlyAdmin() {
        require(msg.sender == GOV_ADMIN, "Not admin");
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

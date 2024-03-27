// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeManagementContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BridgeStorage is UUPSUpgradeable {
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

    BridgeManagementContract public managementContract;
    GasBridge public gasBridge;
    mapping(uint64 => GasClaimable) public claimableGas;
    bool public locked;

    function initialize(
        address _managementContract,
        Config calldata config
    ) public initializer {
        managementContract = BridgeManagementContract(_managementContract);
        gasBridge = GasBridge({
            depositState: State({nonce: 0, root: 0x0}),
            withdrawalState: State({nonce: 0, root: 0x0}),
            config: config
        });
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}

    // Modifiers

    modifier onlyRelayer() {
        require(msg.sender == managementContract.relayer(), "Not relayer");
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == managementContract.governor(), "Not governor");
        _;
    }

    modifier onlySecurityGuard() {
        require(
            msg.sender == managementContract.securityGuard(),
            "Not securityGuard"
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == managementContract.owner(), "Not owner");
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
}

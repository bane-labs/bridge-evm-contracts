// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../bridge/BridgeImpl.sol";
import "./interfaces/ITestBridgeManagement.sol";

contract TestBridge is BridgeImpl {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeImpl() {}

    function initialize(
        address _management,
        uint256 _fee,
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _maxDeposits
    ) public initializer {
        __ReentrancyGuard_init();
        management = IBridgeManagement(_management);
        gasBridge = StorageTypes.GasBridge({
            paused: false,
            depositState: StorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: StorageTypes.State({nonce: 0, root: 0x0}),
            config: StorageTypes.GasConfig({
                fee: _fee,
                minAmount: _minAmount,
                maxAmount: _maxAmount,
                maxDeposits: _maxDeposits
            })
        });
    }

    modifier onlyOwner() {
        require(
            msg.sender == ITestBridgeManagement(address(management)).owner(),
            "Unauthorized"
        );
        _;
    }

    // Authorize the contract owner to upgrade the contract for testing purposes.
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}

    // Additional helper functions for testing purposes.

    function isRegisteredToken(address neoXToken) public view returns (bool) {
        return _isRegisteredToken(neoXToken);
    }

    function getTokenConfig(
        address neoXToken
    ) public view returns (StorageTypes.TokenConfig memory config) {
        config = _getTokenConfig(neoXToken);
        return config;
    }

    function getTokenbridgePaused(
        address neoXToken
    ) public view returns (bool) {
        return tokenBridges[neoXToken].paused;
    }

    function getNeoN3Token(address _neoXToken) public view returns (address) {
        return _getNeoN3Token(_neoXToken);
    }

    function getbridgePaused() public view returns (bool) {
        return bridgePaused;
    }

    function getWithdrawalsPaused() public view returns (bool) {
        return withdrawalsPaused;
    }

    function getTokenDepositState(
        address neoXToken
    ) public view returns (StorageTypes.State memory depositState) {
        return _getTokenDepositState(neoXToken);
    }

    function getTokenWithdrawalState(
        address _neoXToken
    ) public view returns (StorageTypes.State memory withdrawalState) {
        return _getTokenWithdrawalState(_neoXToken);
    }

    function hashTokenBridgeOp(
        address _neoXToken,
        address _neoN3Token,
        uint256 _nonce,
        address _to,
        uint256 _amount
    ) public pure returns (bytes32) {
        return
            TokenBridgeLib._hashTokenBridgeOp(
                _neoN3Token,
                _neoXToken,
                _nonce,
                _to,
                _amount
            );
    }

    function computeTokenRoot(
        bytes32 _previousRoot,
        address _neoN3Token,
        address _neoXToken,
        BridgeLib.DepositData[] calldata _deposits
    ) public pure returns (bytes32) {
        return
            TokenBridgeLib._computeNewTopRoot(
                _previousRoot,
                _neoN3Token,
                _neoXToken,
                _deposits
            );
    }
}

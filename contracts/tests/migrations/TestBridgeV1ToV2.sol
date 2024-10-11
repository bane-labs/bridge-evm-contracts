// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./InitializationLib.sol";
import "./../interfaces/ITestBridgeManagement.sol";
import "../../bridge/BridgeImplV1ToV2.sol";

/// @custom:oz-upgrades-from TestBridge
contract TestBridgeV1ToV2 is BridgeImplV1ToV2 {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeImplV1ToV2() {}

    function upgradeToV2(
        TokenMigrationV1[] calldata _tokenBridgeMigrations
    ) external override reinitializer(2) onlyOwner {
        _upgradeToV2(_tokenBridgeMigrations);
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

    // The following code is just for verifying the initialized state of the contract

    function getCurrentInitializedVersion() external view returns (uint256) {
        return InitializationLib._getInitializableStorageValue()._initialized;
    }
}

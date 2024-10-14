// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BridgeImpl, BridgeLib, StorageTypes, TokenBridgeLib} from "../bridge/BridgeImpl.sol";
import {IBridgeManagement} from "../interfaces/IBridgeManagement.sol";
import {InitializationLib} from "./InitializationLib.sol";
import {ITestBridgeManagement} from "./interfaces/ITestBridgeManagement.sol";

// This TestBridge contract contains additional or overridden functions as an extension of the BridgeImpl contract. This includes:
// - Overridden functions with the onlyAdmin modifier are opened to the testing owner (_authorizeUpgrade and _upgrade functions).
// - Initialization function to initialize the storage slots with the same layout as the layout state of the currently deployed contract.
// - A function getCurrentInitializedVersion() to verify the initialized version of the contract.
// - Additional helper functions for testing purposes.
/// @custom:oz-upgrades-from BridgeImpl
contract TestBridge is BridgeImpl {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeImpl() {}

    modifier onlyOwner() {
        require(
            msg.sender == ITestBridgeManagement(address(management)).owner(),
            "Unauthorized"
        );
        _;
    }

    function initialize(address _management) public initializer {
        __ReentrancyGuard_init();
        management = IBridgeManagement(_management);
        gasBridge = StorageTypes.GasBridge({
            paused: false,
            depositState: StorageTypes.State({nonce: 0, root: 0x0}),
            withdrawalState: StorageTypes.State({nonce: 0, root: 0x0}),
            config: StorageTypes.GasConfig({
                fee: 1e17,
                minAmount: 1e18,
                maxAmount: 1e22,
                maxDeposits: 100
            })
        });
    }

    function upgradeToV2(
        TokenMigration[] calldata _tokenBridgeMigrations
    ) external override reinitializer(2) onlyOwner {
        _upgradeToV2(_tokenBridgeMigrations);
    }

    // Authorize the contract owner to upgrade the contract for testing purposes.
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}

    // This function can be used for verifying the initialized state of the contract
    function getCurrentInitializedVersion() external view returns (uint256) {
        return InitializationLib._getInitializableStorageValue()._initialized;
    }

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

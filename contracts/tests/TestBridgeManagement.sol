// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {InitializationLib} from "./InitializationLib.sol";
import {BridgeManagementImpl} from "../management/BridgeManagementImpl.sol";

// This TestBridgeManagement contract contains additional or overridden functions as an extension of the BridgeManagementImpl contract. This includes:
// - Overridden functions with the onlyAdmin modifier are opened to the testing owner (_authorizeUpgrade and _upgrade functions).
// - Initialization function to initialize the storage slots with the same layout as the layout state of the currently deployed contract.
// - A function getCurrentInitializedVersion() to verify the initialized version of the contract.
/// @custom:oz-upgrades-from BridgeManagementImpl
contract TestBridgeManagement is BridgeManagementImpl {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeManagementImpl() {}

    // Contract storage setup for testing purposes. This setup should mock the currently deployed contract's storage slot layout.
    // Previous initialization functions used to arrive at the current storage slot layout should be summarized here.
    // For example, if a slot allocation was used in version 1 but then removed in version 2's re-initialization, this allocation can just be ignored here since it is not allocated in version 2.

    function initialize(
        address _owner,
        address _relayer,
        uint256 _validatorThreshold,
        address[] calldata _validators,
        address _governor,
        address _securityGuard,
        address _funder
    )
        public
        reinitializer(1)
    {
        // Set storage slots based on currently deployed contract's storage slot layout
        __Ownable_init(_owner);

        _setRelayer(_relayer);
        _setGovernor(_governor);
        _setSecurityGuard(_securityGuard);
        _setFunder(_funder);

        // This is needed to testing migration, i.e., the reinitializer(2) function.
        // Ignore any safety-checks since this is just used for test setup.
        uint256 validatorsLength = _validators.length;
        for (uint256 i = 0; i < validatorsLength; i++) {
            _v1_validators.push(_validators[i]);
        }
        validatorThreshold = _validatorThreshold;
    }

    // Authorize the test owner address to upgrade the contract for testing purposes.
    function upgradeToV2() external override reinitializer(2) onlyOwner {
        _upgradeToV2();
    }

    // Authorize the contract owner to upgrade the contract for testing purposes.
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    // This function can be used for verifying the initialized state of the contract
    function getCurrentInitializedVersion() external view returns (uint256) {
        return InitializationLib._getInitializableStorageValue()._initialized;
    }
}

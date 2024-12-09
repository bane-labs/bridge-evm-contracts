// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {InitializationLib} from "./InitializationLib.sol";
import {BridgeManagementImpl, EnumerableSet} from "../management/BridgeManagementImpl.sol";

using EnumerableSet for EnumerableSet.AddressSet;

// This TestBridgeManagement contract contains additional or overridden functions as an extension of the BridgeManagementImpl contract. This includes:
// - Overridden functions with the onlyAdmin modifier are opened to the testing owner (_authorizeUpgrade and _upgrade functions).
// - Initialization function to initialize the storage slots with the same layout as the layout state of the currently deployed contract.
// - A function getCurrentInitializedVersion() to verify the initialized version of the contract.
/// @custom:oz-upgrades-from BridgeManagementImpl
contract TestBridgeManagement is BridgeManagementImpl {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeManagementImpl() {}

    //////////////////////////////
    // Proxy and Initialization //
    //////////////////////////////

    // Authorize the contract owner to upgrade the contract for testing purposes.
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    // This function can be used for verifying the initialized state of the contract
    function getCurrentInitializedVersion() external view returns (uint256) {
        return InitializationLib._getInitializableStorageValue()._initialized;
    }

    // Previous initialization functions used to arrive at the current storage slot layout should be summarized here.
    // The initialization version should reflect the latest release version of the contract that required a reinitialization.

    // Allow non-admins to initialize the contract for testing purposes.
    function initialize(
        address _owner,
        address _relayer,
        uint256 _validatorThreshold,
        address[] calldata _validators,
        address _governor,
        address _securityGuard,
        address _funder
    )
        external
        reinitializer(2)
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
            require(validatorSet.add(_validators[i]), "Validator already added");
        }
        validatorThreshold = _validatorThreshold;
    }
}

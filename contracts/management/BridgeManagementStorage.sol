// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../library/ManagementLib.sol";
import "./BridgeManagementStorageV1.sol";

/**
 * @dev This contract holds errors, modifiers, internal view functions and functions that directly modify the storage. The modification functions have logical checks but no access-checks. For example, registering a token should only be viable if there is no entry for that token already. However, checking if the msg.sender is allowed to do so should be handled in a higher-level contract (i.e., in this case the corresponding Impl contract).
 */
abstract contract BridgeManagementStorage is
    BridgeManagementStorageV1,
    UUPSUpgradeable
{
    address public constant SELF = 0x1212100000000000000000000000000000000005;
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    error InvalidAddress();
    error InvalidValidatorArray();
    error InvalidValidatorThreshold();

    function _setValidators(
        address[] memory _validators,
        uint256 _threshold
    ) internal {
        uint256 validatorsLength = _validators.length;
        if (validatorsLength == 0) revert InvalidValidatorArray();
        if (_threshold == 0 || _threshold > validatorsLength)
            revert InvalidValidatorThreshold();
        for (uint256 i = 0; i < validatorsLength; i++) {
            if (_validators[i] == address(0)) revert InvalidAddress();
        }
        if (ManagementLib._hasDuplicates(_validators))
            revert InvalidValidatorArray();

        delete validators;
        for (uint256 i = 0; i < validatorsLength; i++) {
            validators.push(_validators[i]);
        }
        validatorThreshold = _threshold;
    }

    function _setRelayer(address _relayer) internal {
        relayer = _relayer;
    }

    function _setGovernor(address _governor) internal {
        governor = _governor;
    }

    function _setSecurityGuard(address _securityGuard) internal {
        securityGuard = _securityGuard;
    }

    function _setFunder(address _funder) internal {
        funder = _funder;
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
     * This override is added because "immutable __self" in UUPSUpgradeable is not available in precompiled contract.
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
     * This override is added because "immutable __self" in UUPSUpgradeable is not available in precompiled contract.
     */
    function _checkNotDelegated() internal view virtual override {
        if (address(this) != SELF) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }
}

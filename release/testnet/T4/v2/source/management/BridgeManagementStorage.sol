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
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    error InvalidAddress();
    error InvalidValidatorArray();
    error InvalidValidatorThreshold();

    function _setValidators(
        address[] calldata _validators,
        uint256 _threshold
    ) internal {
        uint256 validatorsLength = _validators.length;
        // Require at least 2 validators and threshold to be greater than 1.
        if (validatorsLength <= 1) revert InvalidValidatorArray();
        if (_threshold <= 1 || _threshold > validatorsLength)
            revert InvalidValidatorThreshold();
        for (uint256 i = 0; i < validatorsLength; i++) {
            if (_validators[i] == address(0)) revert InvalidAddress();
        }
        if (ManagementLib._hasDuplicates(_validators))
            revert InvalidValidatorArray();

        delete validators;
        for (uint256 i = 0; i < validatorsLength; i++) {
            if (_validators[i] == address(0)) revert InvalidAddress();
            validators.push(_validators[i]);
        }
        validatorThreshold = _threshold;
    }

    function _setRelayer(address _relayer) internal {
        if (_relayer == address(0)) revert InvalidAddress();
        relayer = _relayer;
    }

    function _setGovernor(address _governor) internal {
        if (_governor == address(0)) revert InvalidAddress();
        governor = _governor;
    }

    function _setSecurityGuard(address _securityGuard) internal {
        if (_securityGuard == address(0)) revert InvalidAddress();
        securityGuard = _securityGuard;
    }

    function _setFunder(address _funder) internal {
        if (_funder == address(0)) revert InvalidAddress();
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
}

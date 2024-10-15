// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../library/ManagementLib.sol";
import "./BridgeManagementStorageV1.sol";

using EnumerableSet for EnumerableSet.AddressSet;

/**
 * @dev This contract holds errors, modifiers, internal view functions and functions that directly modify the storage. The modification functions have logical checks but no access-checks. For example, registering a token should only be viable if there is no entry for that token already. However, checking if the msg.sender is allowed to do so should be handled in a higher-level contract (i.e., in this case the corresponding Impl contract).
 */
abstract contract BridgeManagementStorage is
    BridgeManagementStorageV1,
    UUPSUpgradeable
{
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;
    uint256 private constant MIN_VALIDATOR_THRESHOLD = 2;
    uint256 private constant MIN_NR_VALIDATORS = 2;

    error AlreadyValidator(address _validator);
    error InvalidAddress();
    error NotValidator(address _validator);
    error MinValidatorsLimitReached();
    error ValidatorThresholdTooLow();
    error ValidatorThresholdTooHigh();

    function _isValidator(address _validator) internal view returns (bool) {
        return EnumerableSet.contains(validatorSet, _validator);
    }

    function _addValidator(address _validator) internal {
        if (_validator == address(0)) revert InvalidAddress();
        bool isNew = EnumerableSet.add(validatorSet, _validator);
        if (!isNew) revert AlreadyValidator(_validator);
    }

    function _removeValidator(address _validator) internal {
        if (_minimumValidatorsReached()) revert MinValidatorsLimitReached();
        if (EnumerableSet.length(validatorSet) == validatorThreshold)
            revert ValidatorThresholdTooHigh();
        bool removed = EnumerableSet.remove(validatorSet, _validator);
        if (!removed) revert NotValidator(_validator);
    }

    function _minimumValidatorsReached() internal view returns (bool) {
        return EnumerableSet.length(validatorSet) == MIN_NR_VALIDATORS;
    }

    function _incrementValidatorThreshold() internal {
        if (EnumerableSet.length(validatorSet) == validatorThreshold)
            revert ValidatorThresholdTooHigh();
        validatorThreshold++;
    }

    function _decrementValidatorThreshold() internal {
        if (validatorThreshold == MIN_VALIDATOR_THRESHOLD)
            revert ValidatorThresholdTooLow();
        validatorThreshold--;
    }

    function _setValidatorThreshold(uint256 _threshold) internal {
        if (_threshold <= 1) revert ValidatorThresholdTooLow();
        if (_threshold > EnumerableSet.length(validatorSet))
            revert ValidatorThresholdTooHigh();
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

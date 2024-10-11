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
    error InvalidIndex();
    error IncorrectValidator(address _expected, address _provided);
    error InvalidValidatorArray();
    error InvalidValidatorThreshold();
    error AlreadyValidator(address _validator);
    error NotValidator(address _validator);

    function _isValidator(address _validator) internal view returns (bool) {
        return validatorMap[_validator];
    }

    function _addValidator(
        address _validator,
        bool increaseThreshold
    ) internal {
        if (_isValidator(_validator)) revert AlreadyValidator(_validator);
        if (increaseThreshold) {
            validatorThreshold++;
        }
        validatorMap[_validator] = true;
        validators.push(_validator);
    }

    function _removeValidator(
        uint256 _index,
        address _validator,
        bool decreaseThreshold
    ) internal {
        uint256 nrValidators = validators.length;
        if (_index > nrValidators) revert InvalidIndex();
        if (!_isValidator(_validator)) revert NotValidator(_validator);
        if (validators[_index] != _validator)
            revert IncorrectValidator(validators[_index], _validator);
        if (decreaseThreshold) {
            validatorThreshold--;
        } else {
            if (validatorThreshold == nrValidators) {
                revert InvalidValidatorThreshold();
            }
        }
        validatorMap[_validator] = false;
        validators[_index] = validators[validators.length - 1];
        validators.pop();
    }

    function _replaceValidator(
        uint256 _index,
        address _oldValidator,
        address _newValidator
    ) internal {
        if (!_isValidator(_oldValidator)) revert NotValidator(_oldValidator);
        if (_isValidator(_newValidator)) revert AlreadyValidator(_newValidator);
        if (validators[_index] != _oldValidator)
            revert IncorrectValidator(validators[_index], _oldValidator);
        validatorMap[_oldValidator] = false;
        validatorMap[_newValidator] = true;
        validators[_index] = _newValidator;
    }

    function _setValidatorThreshold(uint256 _threshold) internal {
        if (_threshold <= 1) revert InvalidValidatorThreshold();
        if (_threshold > validators.length) revert InvalidValidatorThreshold();
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

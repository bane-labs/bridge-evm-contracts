// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../management/BridgeManagementImpl.sol";

contract TestBridgeManagement is BridgeManagementImpl {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeManagementImpl() {}

    // Authorize the contract owner to upgrade the contract for testing purposes.
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}

    function initialize(
        address _owner,
        address _relayer,
        uint256 _validatorThreshold,
        address[] calldata _validators,
        address _governor,
        address _securityGuard,
        address _funder
    ) public initializer {
        __Ownable_init(_owner);
        _setRelayer(_relayer);
        _setValidators(_validators, _validatorThreshold);
        _setGovernor(_governor);
        _setSecurityGuard(_securityGuard);
        _setFunder(_funder);
    }

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
}

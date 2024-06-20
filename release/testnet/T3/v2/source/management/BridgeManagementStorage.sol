// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/ManagementLib.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BridgeManagementStorage is UUPSUpgradeable {
    address public constant SELF = 0x1212100000000000000000000000000000000005;
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    address internal owner;
    address internal relayer;
    uint8 internal validatorThreshold;
    address[] internal validators;
    address internal governor;
    address internal securityGuard;
    address internal funder;

    constructor() {
        _disableInitializers();
    }

    error InvalidAddress();
    error InvalidValidatorArray();
    error InvalidValidatorThreshold();

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function _setOwner(address _owner) internal {
        owner = _owner;
    }

    function _setValidators(
        address[] memory _validators,
        uint threshold
    ) internal {
        uint256 validatorsLength = _validators.length;
        if (validatorsLength == 0) revert InvalidValidatorArray();
        if (threshold == 0 || threshold > validatorsLength)
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
        validatorThreshold = uint8(threshold);
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
}

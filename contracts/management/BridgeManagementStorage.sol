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

    constructor(
        address _owner,
        address _relayer,
        uint8 _validatorThreshold,
        address[] memory _validators,
        address _governor,
        address _securityGuard,
        address _funder
    ) {
        _disableInitializers();
        _setOwner(_owner);
        _setRelayer(_relayer);
        _setValidators(_validators, _validatorThreshold);
        _setGovernor(_governor);
        _setSecurityGuard(_securityGuard);
        _setFunder(_funder);
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

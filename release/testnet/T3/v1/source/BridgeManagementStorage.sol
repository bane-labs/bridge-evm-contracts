// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./BridgeLib.sol";

contract BridgeManagementStorage is UUPSUpgradeable {
    address public constant SELF = 0x1212100000000000000000000000000000000005;
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    address internal owner = 0xbb03c5030cAC72E290Ae185A8b9b375C58f7A9a6;
    address internal relayer = 0xacC85FFb71f83b9bb264f6d64541926D375a6C1d;
    uint8 internal validatorThreshold = 5;
    address[] internal validators = [
        0x4341C7f6BE8Ae0317FDd7E4e643E2Ff35502D477,
        0xB42fbb03f30424AA903022269FCd62EabBdFCfAE,
        0xD94B88C9D92845256019ee3Bd9b07A57Ca067970,
        0x3A6EAbc45aC029cCfAF49D54593a996f638e7cF7,
        0x97fB9c893C19da2672dbd790Ac9fc406F138584B,
        0xB93Ce875656d56935da316B27860b0FC7B60435a,
        0x394831B50e496a4E85C97aCDbD7943802d897c34
    ];
    address internal governor = 0x897FB2357c9Dbcf81d8C16894b7d0e009e69ba8C;
    address internal securityGuard = 0xe7715472792d680aB4c5837e2131264a6153c89D;

    // Role Restriction Modifiers

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function _setOwner(address _owner) internal {
        owner = _owner;
    }

    function _setValidators(
        address[] calldata _validators,
        uint threshold
    ) internal {
        uint256 nrValidators = _validators.length;
        require(
            nrValidators > 0,
            "Validators array must contain at least one address"
        );
        require(
            threshold > 0 && threshold <= nrValidators,
            "Threshold must be greater than 0 and less than or equal to the number of validators"
        );
        for (uint256 i = 0; i < nrValidators; i++) {
            require(
                _validators[i] != address(0),
                "Validator address cannot be 0x0"
            );
        }
        require(
            BridgeLib._hasDuplicates(_validators) == false,
            "Duplicate validator addresses are not allowed"
        );
        delete validators;
        for (uint256 i = 0; i < nrValidators; i++) {
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

    // Upgrade authorization

    modifier onlyAdmin() {
        require(msg.sender == GOV_ADMIN, "Not admin");
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

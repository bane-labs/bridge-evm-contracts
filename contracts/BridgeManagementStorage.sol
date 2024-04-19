// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./BridgeLib.sol";

contract BridgeManagementStorage is UUPSUpgradeable {
    address public constant SELF = 0x1212100000000000000000000000000000000005;
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    address internal owner = 0xBcd4042DE499D14e55001CcbB24a551F3b954096;
    address internal relayer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint8 internal validatorThreshold = 5;
    address[] internal validators = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x90F79bf6EB2c4f870365E785982E1f101E93b906,
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
        0x976EA74026E726554dB657fA54763abd0C3a0aa9,
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955
    ];
    address internal governor = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    address internal securityGuard = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
    address internal funder = 0xFABB0ac9d68B0B445fB7357272Ff202C5651694a;

    // Role Restriction Modifiers

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
        address[] calldata _validators,
        uint threshold
    ) internal {
        uint256 nrValidators = _validators.length;
        if (nrValidators == 0) revert InvalidValidatorArray();
        if (threshold == 0 || threshold > nrValidators)
            revert InvalidValidatorThreshold();
        for (uint256 i = 0; i < nrValidators; i++) {
            if (_validators[i] == address(0)) revert InvalidAddress();
        }
        if (BridgeLib._hasDuplicates(_validators))
            revert InvalidValidatorArray();

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

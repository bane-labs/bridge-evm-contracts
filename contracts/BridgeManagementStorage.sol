// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BridgeManagementStorage is UUPSUpgradeable {
    address public constant GOV_ADMIN =
        0x1212000000000000000000000000000000000000;

    address public owner = 0xBcd4042DE499D14e55001CcbB24a551F3b954096;
    address public relayer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address[] public validators = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x90F79bf6EB2c4f870365E785982E1f101E93b906,
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
        0x976EA74026E726554dB657fA54763abd0C3a0aa9,
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955
    ];
    uint8 public validatorThreshold = 5;
    address public governor = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    address public securityGuard = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

    struct InitData {
        address relayer;
        address[] validators;
        uint8 validatorThreshold;
        address governor;
        address securityGuard;
    }

    // Upgrade authorization

    modifier onlyAdmin() {
        require(msg.sender == GOV_ADMIN, "Not admin");
        _;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyAdmin {}

    // Role Restriction Modifiers

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Not relayer");
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == governor, "Not governor");
        _;
    }

    modifier onlySecurityGuard() {
        require(msg.sender == securityGuard, "Not securityGuard");
        _;
    }

    function _setOwner(address _owner) internal {
        owner = _owner;
    }

    // The validators array is not expected to be large, so we can use a simple O(n^2) algorithm to check for duplicates.
    function _hasDuplicates(
        address[] calldata addresses
    ) private pure returns (bool) {
        for (uint i = 0; i < addresses.length - 1; i++) {
            for (uint j = i + 1; j < addresses.length; j++) {
                if (addresses[i] == addresses[j]) {
                    return true;
                }
            }
        }
        return false;
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
            _hasDuplicates(_validators) == false,
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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Todo: Before compiling byte code for genesis script, make sure to remove the receive function as it is only used for testing purpose.

contract BridgeManagementContract {
    // Roles
    address public owner;
    address public relayer;
    address[] public validators;
    uint8 public validatorThreshold;

    address public governor;
    address public securityGuard;

    constructor(address _owner, DeploymentData memory _deploymentData) {
        owner = _owner;
        relayer = _deploymentData.relayer;
        validators = _deploymentData.validators;
        validatorThreshold = _deploymentData.validatorThreshold;
        governor = _deploymentData.governor;
        securityGuard = _deploymentData.securityGuard;
    }

    struct DeploymentData {
        address relayer;
        address[] validators;
        uint8 validatorThreshold;
        address governor;
        address securityGuard;
    }

    // Events

    event SetOwner(address owner);
    event SetRelayer(address relayer);
    event SetValidators(address[] validators, uint threshold);
    event SetGovernor(address governor);
    event SetSecurityGuard(address securityGuard);

    // Modifiers
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

    function getValidators() public view returns (address[] memory) {
        return validators;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit SetOwner(_owner);
    }

    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
        emit SetRelayer(_relayer);
    }

    // The validators array is not expected to be large, so we can use a simple O(n^2) algorithm to check for duplicates.
    function hasDuplicate(
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

    function setValidators(
        address[] calldata _validators,
        uint threshold
    ) external onlyOwner {
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
            hasDuplicate(_validators) == false,
            "Duplicate validator addresses are not allowed"
        );
        delete validators;
        for (uint256 i = 0; i < nrValidators; i++) {
            validators.push(_validators[i]);
        }
        validatorThreshold = uint8(threshold);
        emit SetValidators(_validators, threshold);
    }

    function setGovernor(address _governor) external onlyOwner {
        governor = _governor;
        emit SetGovernor(_governor);
    }

    function setSecurityGuard(address _securityGuard) external onlyOwner {
        securityGuard = _securityGuard;
        emit SetSecurityGuard(_securityGuard);
    }
}

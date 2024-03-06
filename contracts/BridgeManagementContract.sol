// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Todo: Before compiling byte code for genesis script, make sure to remove the receive function as it is only used for testing purpose.

contract BridgeManagementContract {
    // Roles
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
    address public governor = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    address public securityGuard = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

    uint8 public validatorThreshold = 5;

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

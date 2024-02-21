// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Todo: Before compiling byte code for genesis script, make sure to remove the receive function as it is only used for testing purpose.

contract BridgeManagementContract {
    // Roles
    address public owner = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
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

    // Bridge parameters
    uint256 public withdrawalFee = 10000000_0000000000;
    uint256 public minWithdrawalAmount = 1_00000000_0000000000;
    uint256 public maxWithdrawalAmount = 10000_00000000_0000000000;
    uint8 public maxDepositsPerDistribution = 100;

    uint8 public requiredValidatorSignaturesForDeposit = 5;
    mapping(address => bool) private addressExists;

    // Events

    event SetOwner(address owner);
    event SetRelayer(address relayer);
    event SetValidators(address[] validators, uint threshold);
    event SetGovernor(address governor);
    event SetSecurityGuard(address securityGuard);

    event WithdrawalFeeChanged(uint256 newFee);
    event MinWithdrawalAmountChanged(uint256 newAmount);
    event MaxWithdrawalAmountChanged(uint256 amount);
    event MaxDepositsPerDistributionChanged(uint8 amount);

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

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit SetOwner(_owner);
    }

    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
        emit SetRelayer(_relayer);
    }

    function hasDuplicate(
        address[] calldata addresses
    ) private returns (bool) {
        for (uint i = 0; i < addresses.length; i++) {
            if (addressExists[addresses[i]]) {
                return true;
            } else {
                addressExists[addresses[i]] = true;
            }
        }
        return false;
    }

    function setValidators(
        address[] calldata _validators,
        uint threshold
    ) external onlyOwner {
        require(
            _validators.length > 0,
            "Validators array must contain at least one address"
        );
        require(
            threshold > 0 && threshold <= _validators.length,
            "Threshold must be greater than 0 and less than or equal to the number of validators"
        );
        for (uint256 i = 0; i < _validators.length; i++) {
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
        for (uint256 i = 0; i < _validators.length; i++) {
            validators.push(_validators[i]);
        }
        requiredValidatorSignaturesForDeposit = uint8(threshold);
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

    // Bridge Parameter Setters

    function setWithdrawalFee(uint256 _fee) external onlyGovernor {
        require(
            (_fee % (10 ** 10)) == 0,
            "Fee must have maximally 8 non-zero decimals"
        );
        withdrawalFee = _fee;
        emit WithdrawalFeeChanged(_fee);
    }

    function setMinWithdrawalAmount(uint256 _amount) external onlyGovernor {
        require(
            (_amount % (10 ** 10)) == 0,
            "Amount must have maximally 8 non-zero decimals"
        );
        require(
            _amount < maxWithdrawalAmount,
            "Amount must be less than the maximal withdrawal amount"
        );
        minWithdrawalAmount = _amount;
        emit MinWithdrawalAmountChanged(_amount);
    }

    function setMaxWithdrawalAmount(uint256 _amount) external onlyGovernor {
        require(
            (_amount % (10 ** 10)) == 0,
            "Amount must have maximally 8 non-zero decimals"
        );
        require(
            _amount > minWithdrawalAmount,
            "Amount must be greater than the minimal withdrawal amount"
        );
        maxWithdrawalAmount = _amount;
        emit MaxWithdrawalAmountChanged(_amount);
    }

    function setMaxDepositsPerDistribution(
        uint8 _maxDepositsPerDistribution
    ) external onlyGovernor {
        require(
            _maxDepositsPerDistribution > 0,
            "Value must be greater than 0"
        );
        maxDepositsPerDistribution = _maxDepositsPerDistribution;
        emit MaxDepositsPerDistributionChanged(_maxDepositsPerDistribution);
    }
}

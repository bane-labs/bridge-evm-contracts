// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./BridgeManagementContract.sol";

// Todo: Before compiling byte code for genesis script, make sure to remove the receive function as it is only used for testing purpose.

contract BridgeContract {
    BridgeManagementContract managementContract;

    bool public locked = false;

    // Initial deposit and withdrawal values
    uint64 public depositNonce = 0;
    uint64 public withdrawalNonce = 0;

    bytes32 public depositRoot;
    bytes32 public withdrawalRoot;

    mapping(uint64 => address) public claimableTo;
    mapping(uint64 => uint64) public claimableAmount; // Holds the claimable amount values with 8 decimal places

    // Bridge parameters
    uint256 public withdrawalFee = 10000000_0000000000;
    uint256 public minWithdrawalAmount = 1_00000000_0000000000;
    uint256 public maxWithdrawalAmount = 10000_00000000_0000000000;
    uint8 public maxDepositsPerDistribution = 100;

    // Events

    event Deposit(uint64 nonce, uint64 amount, address to);
    event Claimable(uint64 nonce, uint64 amount, address to);
    event Claimed(uint64 nonce, uint64 amount, address to);

    event Withdrawal(
        uint64 nonce,
        uint64 amount,
        address to,
        address from,
        bytes32 withdrawalHash,
        bytes32 withdrawalRoot
    );
    event WithdrawalFeeChanged(uint256 newFee);
    event MinWithdrawalAmountChanged(uint256 newAmount);
    event MaxWithdrawalAmountChanged(uint256 amount);
    event MaxDepositsPerDistributionChanged(uint8 amount);

    // This is only used for testing. Remove it before compiling byte code for genesis script.
    receive() external payable onlyRelayer {}

    constructor(address _managementContract) {
        managementContract = BridgeManagementContract(_managementContract);
    }

    //////////////////////////
    // Deposit Verification //
    //////////////////////////

    struct DepositData {
        address payable to;
        uint64 amount;
        uint64 nonce;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /////////////
    // Deposit //
    /////////////

    function deposit(
        bytes32 _depositRoot,
        Signature[] calldata _signatures,
        DepositData[] calldata _deposits
    ) external onlyRelayer unlocked {
        uint depositLength = _deposits.length;
        require(depositLength > 0, "At least 1 deposit is required.");
        require(
            depositLength <= maxDepositsPerDistribution,
            "Too many deposits provided."
        );
        require(
            _deposits[0].nonce == depositNonce + 1,
            "Only the next nonce is allowed in the first proof."
        );
        require(
            subsequentNonces(_deposits, depositNonce),
            "The nonces of the proofs must be subsequent."
        );

        require(
            verifyValidatorSignatures(_depositRoot, _signatures),
            "Invalid or insufficient validator signatures."
        );
        depositNonce = _deposits[depositLength - 1].nonce;
        bytes32 formerDepositRoot = depositRoot;
        depositRoot = _depositRoot;
        verifyDepositsAndTransfer(formerDepositRoot, _deposits);
    }

    // Makes sure the proofs have subsequent nonces.
    function subsequentNonces(
        DepositData[] calldata _deposits,
        uint64 startNonce
    ) private pure returns (bool) {
        for (uint8 i = 1; i <= _deposits.length; i++) {
            if (_deposits[i - 1].nonce != startNonce + i) {
                return false;
            }
        }
        return true;
    }

    function verifyDepositsAndTransfer(
        bytes32 _formerDepositRoot,
        DepositData[] calldata _deposits
    ) private {
        bytes32 parent = _formerDepositRoot;
        uint depositsLength = _deposits.length;
        for (uint i = 0; i < depositsLength; i++) {
            DepositData calldata depositData = _deposits[i];
            bytes32 depositHash = hashDepositOrWithdrawal(
                depositData.nonce,
                depositData.amount,
                depositData.to
            );
            parent = computeNewRoot(parent, depositHash);
        }
        if (parent != depositRoot) {
            revert("Invalid deposit root.");
        }

        // Once this is reached, execute the deposits
        for (uint i = 0; i < depositsLength; i++) {
            DepositData calldata depositEntry = _deposits[i];
            address to = depositEntry.to;
            if (!isContract(to)) {
                uint256 sendValue = addTenDecimals(depositEntry.amount);
                // Todo: Verify that this call works as expected, i.e., the funds have not been sent if it returns false.
                (bool success, ) = to.call{value: sendValue}("");
                if (success) {
                    emit Deposit(depositEntry.nonce, depositEntry.amount, to);
                } else {
                    addToClaim(depositEntry);
                    emit Claimable(depositEntry.nonce, depositEntry.amount, to);
                }
            } else {
                addToClaim(depositEntry);
                emit Claimable(depositEntry.nonce, depositEntry.amount, to);
            }
        }
    }

    function computeNewRoot(
        bytes32 formerRoot,
        bytes32 depositHash
    ) private pure returns (bytes32) {
        return sha256(abi.encodePacked(formerRoot, depositHash));
    }

    function addToClaim(DepositData calldata _deposit) private {
        claimableTo[_deposit.nonce] = _deposit.to;
        claimableAmount[_deposit.nonce] = _deposit.amount;
    }

    function verifyValidatorSignatures(
        bytes32 _newDepositRoot,
        Signature[] calldata _signatures
    ) private view returns (bool) {
        uint8 threshold = managementContract
            .requiredValidatorSignaturesForDeposit();
        require(
            _signatures.length == threshold,
            "Invalid number of signatures."
        );
        bytes32 signedRootMsg = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_newDepositRoot))
            )
        );
        address[] memory recovered = new address[](threshold);
        for (uint i = 0; i < threshold; i++) {
            Signature calldata sig = _signatures[i];
            recovered[i] = ecrecover(signedRootMsg, sig.v, sig.r, sig.s);
        }
        // check if all recovered addresses are in the validator set
        uint covered = 0;
        uint n = 0;
        uint j;
        address[] memory validators = managementContract.getValidators();
        for (uint i = 0; i < threshold; i++) {
            for (j = n; j < validators.length; j++) {
                if (recovered[i] == validators[j]) {
                    covered++;
                    break;
                }
            }
            n = j + 1;
        }
        return covered == 5;
    }

    function isContract(address _addr) private view returns (bool) {
        return _addr.code.length > 0;
    }

    // Modifiers

    modifier onlyRelayer() {
        require(msg.sender == managementContract.relayer(), "Not relayer");
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == managementContract.governor(), "Not governor");
        _;
    }

    modifier onlySecurityGuard() {
        require(
            msg.sender == managementContract.securityGuard(),
            "Not securityGuard"
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == managementContract.owner(), "Not owner");
        _;
    }

    modifier unlocked() {
        require(!locked, "Contract is locked");
        _;
    }

    ///////////
    // Claim //
    ///////////

    // Anyone can execute a claim. The funds of a claimable will be sent to the defined address in the claimableTo mapping.
    function claim(uint64 _nonce) external unlocked {
        address payable to = payable(claimableTo[_nonce]);
        uint64 claimAmount = claimableAmount[_nonce];
        require(claimableAmount[_nonce] != 0, "No claimable funds");
        require(to != address(0), "No claimable funds");

        delete claimableAmount[_nonce];
        delete claimableTo[_nonce];
        uint256 sendValue = addTenDecimals(claimAmount);
        (bool success, ) = to.call{value: sendValue}("");
        if (!success) {
            revert("Transfer failed");
        }
        emit Claimed(_nonce, claimAmount, to);
    }

    ////////////////
    // Withdrawal //
    ////////////////

    function withdraw(address _to) external payable unlocked {
        require(_to != address(0), "Address must not be the zero address");
        require(
            (msg.value % (10 ** 10)) == 0,
            "Only amounts with maximally 8 non-zero decimals are allowed for withdrawals"
        );

        uint256 actualWithdrawalAmount = msg.value - withdrawalFee;
        require(
            actualWithdrawalAmount >= minWithdrawalAmount,
            "Withdrawal amount is too low"
        );
        require(
            actualWithdrawalAmount <= maxWithdrawalAmount,
            "Withdrawal amount is too high"
        );

        withdrawalNonce++;
        uint64 hashAmount = removeTenDecimals(actualWithdrawalAmount);
        bytes32 withdrawalHash = hashDepositOrWithdrawal(
            withdrawalNonce,
            hashAmount,
            _to
        );
        withdrawalRoot = computeNewWithdrawalRoot(
            withdrawalRoot,
            withdrawalHash
        );
        emit Withdrawal(
            withdrawalNonce,
            hashAmount,
            _to,
            msg.sender,
            withdrawalHash,
            withdrawalRoot
        );
    }

    function hashDepositOrWithdrawal(
        uint64 _nonce,
        uint64 _amount,
        address _to
    ) private pure returns (bytes32) {
        return sha256(abi.encodePacked(_nonce, _amount, _to));
    }

    function computeNewWithdrawalRoot(
        bytes32 _previousWithdrawalRoot,
        bytes32 _newWithdrawalHash
    ) private pure returns (bytes32) {
        return
            sha256(
                abi.encodePacked(_previousWithdrawalRoot, _newWithdrawalHash)
            );
    }

    // Adds 10 decimals to the amount. GasToken originally has 8 decimals and on this chain it has 18 decimals.
    function addTenDecimals(uint64 _value) private pure returns (uint256) {
        return uint256(_value) * (10 ** 10);
    }

    // Removes 10 decimal points from the amount. GasToken originally has 8 decimals and on this chain it has 18 decimals.
    function removeTenDecimals(uint256 _value) private pure returns (uint64) {
        return uint64(_value / (10 ** 10));
    }

    // Contract Locking

    function lock() external onlySecurityGuard unlocked {
        locked = true;
    }

    function unlock() external onlyGovernor {
        require(locked, "Contract is already locked");
        locked = false;
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

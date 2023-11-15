// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Todo: Before compiling byte code for genesis script, make sure to set the correct values for the following variables:
// - relayer
// - validators
// - minWithdrawalAmount
// - maxWithdrawalAmount
// - remove the receive function as it is only used for testing purpose.

contract HashTreeBridgeContract {
    // Todo: Discuss using values hardcoded here as default and adding an overwrite functionality.
    address public constant relayer =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address[] public validators = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x90F79bf6EB2c4f870365E785982E1f101E93b906,
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
        0x976EA74026E726554dB657fA54763abd0C3a0aa9,
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955
    ];

    uint256 public constant minWithdrawalAmount = 1_00000000_0000000000;
    uint256 public constant maxWithdrawalAmount = 10000_00000000_0000000000;

    bytes32 public depositRoot;
    bytes32 public withdrawalRoot;
    uint64 public depositNonce = 0;
    uint64 public withdrawalNonce = 0;

    mapping(uint64 => address) public claimableTo;
    // Important: The claimableAmount mapping contains the uint64 value that is still the value with 8 decimal places.
    mapping(uint64 => uint64) public claimableAmount;

    // Events

    event Deposit(uint64 nonce, uint64 amount, address to);
    event Claimable(uint64 nonce, uint64 amount, address to);
    event Claimed(uint64 nonce, uint64 amount, address to);

    event Withdrawal(uint64 nonce, uint64 amount, address to, address from);

    // Todo: This is only used for testing. Remove it before compiling byte code for genesis script.
    receive() external payable onlyRelayer {}

    //////////////////////////
    // Deposit Verification //
    //////////////////////////

    // Todo: Introduce limit for max mint amount -> max amount limit should be handled in Bridge contract on Neo.

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
    ) external onlyRelayer {
        require(_deposits.length > 0, "At least 1 deposit is required.");
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
        depositNonce = _deposits[_deposits.length - 1].nonce;
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
            require(depositData.to != address(0), "Address must not be the zero address");
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
        bytes32 signedRootMsg = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_newDepositRoot))
            )
        );
        address[] memory recovered = new address[](5);
        for (uint i = 0; i < 5; i++) {
            Signature calldata sig = _signatures[i];
            recovered[i] = ecrecover(signedRootMsg, sig.v, sig.r, sig.s);
        }
        // check if all recovered addresses are in the validator set
        uint covered = 0;
        uint n = 0;
        uint j;
        for (uint i = 0; i < 5; i++) {
            for (j = n; j < 7; j++) {
                if (recovered[i] == validators[j]) {
                    covered++;
                    break;
                }
            }
            n = j;
        }
        return covered == 5;
    }

    function isContract(address _addr) private view returns (bool) {
        return _addr.code.length > 0;
    }

    // Modifier

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Not relayer");
        _;
    }

    ///////////
    // Claim //
    ///////////

    // Anyone can execute a claim. The funds of a claimable will be sent to the defined address in the claimableTo mapping.
    function claim(uint64 _nonce) external {
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

    function withdraw(address _to) external payable {
        require(_to != address(0), "Address must not be the zero address");

        require(
            (msg.value % (10 ** 10)) == 0,
            "Only amounts with 8 non-zero decimals allowed for withdrawal"
        );
        require(
            msg.value >= minWithdrawalAmount,
            "Smaller than minimum withdrawal amount"
        );
        require(
            msg.value <= maxWithdrawalAmount,
            "Larger than maximum withdrawal amount"
        );

        withdrawalNonce++;
        uint64 hashAmount = removeTenDecimals(msg.value);
        bytes32 withdrawalHash = hashDepositOrWithdrawal(
            withdrawalNonce,
            hashAmount,
            _to
        );
        withdrawalRoot = computeNewWithdrawalRoot(
            withdrawalRoot,
            withdrawalHash
        );
        // Todo: Consider passing the new withdrawalRoot in the Withdrawal event as well.
        emit Withdrawal(withdrawalNonce, hashAmount, _to, msg.sender);
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
}

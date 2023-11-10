// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Todo: Before compiling byte code for genesis script, make sure to set the correct values for the following variables:
// - relayer
// - validators
// - minWithdrawalAmount
// - maxWithdrawalAmount
// - remove the receive function as it is only used for testing purpose.

contract AppLogsBridgeContract {
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
    uint64 public depositNonce = 0;
    uint64 public withdrawalNonce = 0;

    mapping(uint64 => address) public claimableTo;
    mapping(uint64 => uint64) public claimableAmount;

    // Events

    event Claimable(uint64 nonce, uint64 amount, address to);
    event Deposit(uint64 nonce, uint64 amount, address to);
    event Withdrawal(uint64 nonce, uint256 amount, address to, address from);

    // Todo: This is only used for testing. Remove it before compiling byte code for genesis script.
    receive() external payable onlyRelayer {}

    //////////////////////////
    // Deposit Verification //
    //////////////////////////

    // Todo: Introduce limit for max mint amount -> max amount limit should be handled in Bridge contract on Neo.

    struct DepositWithProof {
        address payable to;
        uint64 amount;
        uint64 nonce;
        uint64 path;
        bytes32[] proof;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // Deposit

    // The validators compute the merkle tree root from the notification of the deposits that happened on Neo N3.
    // They sign the root of that merkle tree and provide their signature to the relayer. The relayer then computes the
    // merkle tree as well and verifies it agains the signatures provided by the validators and their respective public
    // keys. If they match and the relayer has collected 5 signatures, he'll compute the proofs for the included
    // deposits. Once computed, the relayer builds a transaction to invoke the following deposit function with the new
    // root, the 5 valdiator signatures and the included deposits with their respective proofs.
    function deposit(
        bytes32 _newDepositRoot,
        Signature[] calldata _signatures,
        DepositWithProof[] calldata _deposits
    ) external onlyRelayer {
        // Input Validation Checks
        require(_deposits.length > 0, "At least 1 deposit is required.");

        // Check Subsequent Nonces
        require(
            _deposits[0].nonce == depositNonce + 1,
            "Only the next nonce is allowed in the first proof."
        );
        require(
            subsequentNonces(_deposits, depositNonce),
            "The nonces of the proofs must be subsequent."
        );

        // Check Validator Signatures
        require(
            verifyValidatorSignatures(_newDepositRoot, _signatures),
            "Invalid or insufficient validator signatures."
        );

        // Updating Root and Nonce before verifying and transferring funds
        depositNonce = _deposits[_deposits.length - 1].nonce;
        depositRoot = _newDepositRoot;

        // Verify all Proofs and Transfer Funds
        verifyDepositsAndTransfer(depositRoot, _deposits);
    }

    // Makes sure the proofs have subsequent nonces.
    function subsequentNonces(
        DepositWithProof[] calldata _deposits,
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
        bytes32 _depositRoot,
        DepositWithProof[] calldata _deposits
    ) private {
        for (uint i = 0; i < _deposits.length; i++) {
            DepositWithProof calldata depositEntry = _deposits[i];
            if (!verify(_depositRoot, depositEntry)) {
                revert("Invalid proof provided for a deposit.");
            }
            if (!isContract(depositEntry.to)) {
                uint256 sendValue = addTenDecimals(depositEntry.amount);
                // Todo: Verify that this call works as expected, i.e., the funds have not been sent if it returns false.
                (bool success, ) = depositEntry.to.call{value: sendValue}("");
                if (!success) {
                    addToClaim(depositEntry);
                    emit Claimable(
                        depositEntry.nonce,
                        depositEntry.amount,
                        depositEntry.to
                    );
                } else {
                    emit Deposit(
                        depositEntry.nonce,
                        depositEntry.amount,
                        depositEntry.to
                    );
                }
            } else {
                addToClaim(depositEntry);
                emit Claimable(
                    depositEntry.nonce,
                    depositEntry.amount,
                    depositEntry.to
                );
            }
        }
    }

    function verify(
        bytes32 _depositRoot,
        DepositWithProof calldata _deposit
    ) private pure returns (bool) {
        bytes32 parent = hashDepositOrWithdrawal(
            _deposit.nonce,
            _deposit.amount,
            _deposit.to
        );
        bytes32[] calldata proof = _deposit.proof;
        uint proofLength = proof.length;
        uint64 path = _deposit.path;
        uint height = 0;
        for (uint i = 0; i < proofLength; i++) {
            // If the bit on position `height` is 1, the i-th proof element is the right child of the next parent.
            if ((path >> height) == 1) {
                parent = computeParentHash(parent, proof[i]);
            } else {
                parent = computeParentHash(proof[i], parent);
            }
            height += 1;
        }
        return parent == _depositRoot;
    }

    function addToClaim(DepositWithProof calldata _deposit) private {
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

    ////////////////
    // Withdrawal //
    ////////////////

    function withdraw(address _to) external payable {
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
        emit Withdrawal(
            withdrawalNonce,
            removeTenDecimals(msg.value),
            _to,
            msg.sender
        );
    }

    function hashDepositOrWithdrawal(
        uint64 _nonce,
        uint64 _amount,
        address _to
    ) private pure returns (bytes32) {
        return sha256(abi.encodePacked(_nonce, _amount, _to));
    }

    function computeParentHash(
        bytes32 _left,
        bytes32 _right
    ) private pure returns (bytes32) {
        return sha256(abi.encodePacked(_left, _right));
    }

    // Adds 10 decimals to the amount. GasToken originally has 8 decimals and on this chain it has 18 decimals.
    function addTenDecimals(uint256 _value) private pure returns (uint256) {
        return _value * (10 ** 10);
    }

    // Removes 10 decimal points from the amount. GasToken originally has 8 decimals and on this chain it has 18 decimals.
    function removeTenDecimals(uint256 _value) private pure returns (uint256) {
        return _value / (10 ** 10);
    }
}

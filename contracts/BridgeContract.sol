// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Todo: Before compiling byte code for genesis script, make sure to set the correct values for the following variables:
// - relayer
// - validators
// - minWithdrawalAmount
// - maxWithdrawalAmount
// - remove the receive function as it is only used for testing purpose.

contract Bridge {
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

    bytes32 public withdrawalRoot;
    // Bundle smaller variables types together to optimize slot usage.
    uint32 public depositNonce;

    uint32 public maxDepth;
    uint32 public withdrawalNonce;

    mapping(uint256 => bytes32) rootMap;

    // Events

    event Deposit(uint _nonce, address _to, uint _value);
    event Withdrawal(
        uint _nonce,
        address from,
        address _to,
        uint _amount,
        bytes32 _withdrawalHash,
        bytes32 _root
    );

    // Todo: This is only used for testing.
    receive() external payable onlyRelayer {}

    //////////////////////////
    // Deposit Verification //
    //////////////////////////

    // Todo: Introduce limit for max mint amount -> max amount limit should be handled in Bridge contract on Neo.

    // Deposit Structs
    struct MerkleProof {
        uint32 nonce;
        address payable to;
        uint64 amount;
        bytes32[] proof;
        bytes32 root;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // Deposit

    function deposit(
        MerkleProof[] calldata _proofs,
        Signature[] calldata _signatures
    ) external onlyRelayer {
        require(_proofs.length > 0, "At least 1 proof is required.");
        // Todo: Discuss upperbound for number of proofs per transaction.
        require(_proofs.length <= 10, "At most 10 proofs are allowed.");
        require(
            _proofs[0].nonce == depositNonce + 1,
            "Only the next nonce is allowed in the first proof."
        );
        require(
            subsequentNonces(_proofs, depositNonce),
            "The nonces of the proofs must be subsequent."
        );
        require(
            _signatures.length == 5,
            "Distribution requires exactly 5 signatures of the 7 validators."
        );
        require(
            buildMsgAndVerifyValidatorSignatures(_signatures, _proofs),
            "Validator signature verification failed."
        );

        verifyProofsAndTransfer(_proofs);
        depositNonce = _proofs[_proofs.length - 1].nonce;
    }

    // Makes sure the proofs have subsequent nonces.
    function subsequentNonces(
        MerkleProof[] calldata _proofs,
        uint32 startNonce
    ) private pure returns (bool) {
        for (uint8 i = 1; i <= _proofs.length; i++) {
            if (_proofs[i - 1].nonce != startNonce + i) {
                return false;
            }
        }
        return true;
    }

    function verifyProofsAndTransfer(MerkleProof[] calldata _proofs) private {
        for (uint i = 0; i < _proofs.length; i++) {
            MerkleProof calldata proof = _proofs[i];
            if (verify(proof)) {
                address payable to = proof.to;
                uint256 transferAmount = toEthDecimals(proof.amount);
                if (!isContract(to)) {
                    if (to.send(transferAmount)) {
                        emit Deposit(proof.nonce, to, proof.amount);
                    } else {
                        // Todo: What happens if the transfer fails?
                        // emit FailedDeposit(proof.nonce, to, proof.amount);
                    }
                }
                // In case the recipient is a contract, no funds are sent. However, the Merkle Tree computation must withstand.
                // Todo: Discuss if we want to provide refund support in case the recipient is a contract.
                // emit FailedDeposit(proof.nonce, to, proof.amount);
            } else {
                // If a proof verification failed, the transaction is reverted.
                revert();
            }
        }
    }

    function verify(MerkleProof calldata _proof) private pure returns (bool) {
        bytes32 right = sha256(
            abi.encodePacked(_proof.nonce, _proof.to, _proof.amount)
        );
        for (uint i = 0; i < _proof.proof.length; i++) {
            right = sha256(abi.encodePacked(_proof.proof[i], right));
        }
        return right == _proof.root;
    }

    function buildMsgAndVerifyValidatorSignatures(
        Signature[] calldata _signatures,
        MerkleProof[] calldata _proofs
    ) private view returns (bool) {
        bytes32 rootsMsgHash = concatRootsAndCreateMessage(_proofs);
        return verifyValidatorSignatures(_signatures, rootsMsgHash);
    }

    function verifyValidatorSignatures(
        Signature[] calldata _signatures,
        bytes32 _msgHash
    ) private view returns (bool) {
        require(
            _signatures.length == 5,
            "Distribution requires 5 signatures of the 7 validators."
        );
        address[] memory recovered = new address[](5);
        for (uint i = 0; i < 5; i++) {
            Signature calldata sig = _signatures[i];
            recovered[i] = ecrecover(_msgHash, sig.v, sig.r, sig.s);
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

    function concatRootsAndCreateMessage(
        MerkleProof[] calldata _proofs
    ) private pure returns (bytes32) {
        bytes memory concatRoots = abi.encode(_proofs[0].root);
        for (uint i = 1; i < _proofs.length; i++) {
            concatRoots = abi.encodePacked(concatRoots, _proofs[i].root);
        }
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(concatRoots)
                )
            );
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

        withdrawalNonce++;
        bytes32 withdrawalHash = hashWithdrawal(
            withdrawalNonce,
            _to,
            msg.value
        );
        bytes32 root = updateWithdrawalMerkleTree(withdrawalHash);
        withdrawalRoot = root;
        emit Withdrawal(
            withdrawalNonce,
            msg.sender,
            _to,
            msg.value,
            withdrawalHash,
            root
        );
    }

    function hashWithdrawal(
        uint32 _withdrawalNonce,
        address _to,
        uint256 _amount
    ) private pure returns (bytes32) {
        return sha256(abi.encodePacked(_withdrawalNonce, _to, _amount));
    }

    function updateWithdrawalMerkleTree(
        bytes32 _withdrawalHash
    ) private returns (bytes32) {
        uint32 max = maxDepth;
        bool carry = true;
        bytes32 right = _withdrawalHash;
        for (uint i = 0; i <= max; i++) {
            bool stored = rootMap[i] != 0x00;
            if (stored) {
                right = computeParentHash(rootMap[i], right);
                if (carry) {
                    delete rootMap[i];
                    if (i == max) {
                        maxDepth += 1;
                        rootMap[maxDepth + 1] = right;
                    }
                }
            } else {
                if (carry) {
                    rootMap[i] = right;
                }
                carry = false;
            }
        }
        return right;
    }

    function computeParentHash(
        bytes32 _left,
        bytes32 _right
    ) private pure returns (bytes32) {
        return sha256(abi.encodePacked(_left, _right));
    }

    // Adds 10 decimals to the amount. GasToken originally has 8 decimals and on Bane it has 18 decimals.
    function toEthDecimals(uint256 _value) private pure returns (uint256) {
        return _value * (10 ** 10);
    }
}

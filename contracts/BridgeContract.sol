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

    bytes32 public depositRoot;
    uint64 public depositNonce;

    uint32 maxDepth;

    bytes32 public withdrawalRoot;
    uint64 public withdrawalNonce;

    mapping(uint256 => bytes32) public rootMap;

    // Events

    event Deposit(uint64 _nonce, address _to, uint _value);
    event Withdrawal(
        uint64 _nonce,
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
        uint64 nonce;
        address payable to;
        uint64 amount;
        uint64 path;
        bytes32[] proof;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // Deposit

    /**
     * @notice This function is used to deposit funds from Neo N3 and is restricted to the relayer.
     * @dev Distributes deposits to the respective recipients.
     */
    function deposit(
        bytes32 _depositRoot,
        uint64 _lastNonce,
        Signature[] calldata _signatures,
        MerkleProof[] calldata _proofs
    ) external onlyRelayer {
        // Logical Parameter Checks
        uint nrProofs = _proofs.length;
        require(nrProofs > 0, "At least 1 proof is required.");
        // Todo: Discuss upperbound for number of proofs per transaction. If not required, remove this check.
        require(nrProofs <= 10, "At most 10 proofs are allowed.");
        require(
            _proofs[0].nonce == depositNonce + 1,
            "Only the next nonce is allowed in the first proof."
        );
        require(
            _proofs[nrProofs - 1].nonce == depositNonce + _lastNonce,
            "Must provide all proofs that have not been processed under the provided root."
        );
        require(
            subsequentNonces(_proofs, depositNonce),
            "The nonces of the proofs must be subsequent."
        );

        // Validator Signature Check
        require(
            _signatures.length == 5,
            "Distribution requires exactly 5 signatures of the 7 validators."
        );
        require(
            buildMsgAndVerifyValidatorSignatures(
                _depositRoot,
                _lastNonce,
                _signatures
            ),
            "Validator signature verification failed."
        );

        // Updating Root and Nonce
        depositRoot = _depositRoot;
        depositNonce = _proofs[_proofs.length - 1].nonce;

        // Verify all Proofs and Transfer Funds
        verifyProofsAndTransfer(_proofs);
    }

    // Makes sure the proofs have subsequent nonces.
    function subsequentNonces(
        MerkleProof[] calldata _proofs,
        uint64 startNonce
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
            MerkleProof calldata p = _proofs[i];
            if (verify(p)) {
                if (isContract(p.to)) {
                    // Todo: Implement claim functionality. Anyone should be able to claim the deposit if the recipient is a contract, since the funds will be transferred to the contract address.
                    // Todo: Consider adding functionality to move deposit to withdrawal without claiming. Only the recipient should be able to do this.
                } else {
                    uint256 transferAmount = toEthDecimals(p.amount);
                    if (p.to.send(transferAmount)) {
                        emit Deposit(p.nonce, p.to, p.amount);
                    } else {
                        // Todo: Implement claim functionality.
                        // Todo: Consider adding functionality to move deposit to withdrawal without claiming. Only the recipient should be able to do this.
                        // Consider emitting an event here.
                    }
                }
            } else {
                // If a proof verification failed, the transaction is reverted.
                revert();
            }
        }
    }

    function verify(MerkleProof calldata _p) private view returns (bool) {
        bytes32 parent = sha256(abi.encodePacked(_p.nonce, _p.to, _p.amount));
        uint height = 0;
        for (uint i = 0; i < _p.proof.length; i++) {
            // If the path bit at the current height is 1, the proof element is on the right side. Otherwise it is on the left side.
            if ((_p.path >> height) & 1 == 1) {
                parent = computeParentHash(parent, _p.proof[i]);
            } else {
                parent = computeParentHash(_p.proof[i], parent);
            }
            height += 1;
        }
        return parent == depositRoot;
    }

    function buildMsgAndVerifyValidatorSignatures(
        bytes32 _depositRoot,
        uint64 _lastNonce,
        Signature[] calldata _signatures
    ) private view returns (bool) {
        bytes32 depositMsg = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_depositRoot, _lastNonce))
            )
        );

        return verifyValidatorSignatures(depositMsg, _signatures);
    }

    function verifyValidatorSignatures(
        bytes32 _msgHash,
        Signature[] calldata _signatures
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
        uint64 _withdrawalNonce,
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

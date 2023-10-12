// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Bridge {
    
    // To set when compiling contract for loading its bytes into genesis script.
    address public constant relayer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address[7] public validators = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x90F79bf6EB2c4f870365E785982E1f101E93b906,
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
        0x976EA74026E726554dB657fA54763abd0C3a0aa9,
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955
    ];
    uint256 public constant minWithdrawalAmount = 1_00000000_0000000000;
    
    // Bundle smaller variables types together to optimize slot usage.
    uint32 public depositNonce;

    uint32 public maxIndex;
    uint32 public withdrawalNonce;

    mapping(uint256 => bytes32) rootMap;

    // Events

    event Deposit(uint _nonce, address _to, uint _value);
    event Withdrawal(uint _nonce, address _recipient, uint _value);

    //////////////////////////
    // Deposit Verification //
    //////////////////////////

    // Todo: Introduce limit for max mint amount -> max amount limit should be handled in Bridge contract on Neo.

    // Deposit Structs
    struct MerkleProof {
        uint32 nonce;
        address payable recipient;
        uint256 amount;
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
    )
        public
        onlyRelayer
    {
        require(_proofs.length > 0, "At least 1 proof is required.");
        // Todo: Discuss upperbound for number of proofs per transaction.
        require(_proofs.length <= 10, "At most 10 proofs are allowed.");
        require(_proofs[0].nonce == depositNonce + 1, "Only the next nonce is allowed in the first proof.");
        require(subsequentNonces(_proofs, depositNonce), "The nonces of the proofs must be subsequent.");
        require(_signatures.length == 5, "Distribution requires 5 signatures of the 7 validators.");
        require(verifyValidatorSignatures(_signatures, _proofs), "Validator signature verification failed.");

        verifyProofsAndTransfer(_proofs);
        depositNonce = _proofs[_proofs.length-1].nonce;
    }

    // Makes sure the proofs have subsequent nonces.
    function subsequentNonces(
        MerkleProof[] calldata _proofs,
        uint32 startNonce
    )
        pure
        private
        returns (bool)
    {
        for (uint8 i = 1; i <= _proofs.length; i++) {
            if (_proofs[i-1].nonce != startNonce + i) {
                return false;
            }
        }
        return true;
    }

    function verifyProofsAndTransfer(
        MerkleProof[] calldata _proofs
    )
        private
    {
        for (uint i = 0; i < _proofs.length; i++) {
            MerkleProof calldata proof = _proofs[i];
            if (verify(proof)) {
                address payable to = proof.recipient;
                if (!isContract(to)) {
                    assert(to.send(proof.amount));
                    emit Deposit(proof.nonce, to, proof.amount);
                }
                // In case the recipient is a contract, no funds are sent. However, the Merkle Tree computation must withstand.
            } else {
                // If a proof verification failed, the transaction is reverted.
                revert();
            }
        }
    }

    function verify(
        MerkleProof calldata _proof
    )
        pure
        private
        returns (bool)
    {
        bytes32 right = sha256(abi.encodePacked(_proof.nonce, _proof.recipient, _proof.amount));
        for (uint i = 0; i < _proof.proof.length; i++) {
            right = sha256(abi.encodePacked(_proof.proof[i], right));
        }
        return right == _proof.root;
    }

    function verifyValidatorSignatures(
        Signature[] calldata _signatures,
        MerkleProof[] calldata _proofs
    )
        view
        private
        returns (bool)
    {
        bytes32 rootsMsgHash = concatRootsAndCreateMessage(_proofs);
        uint8 j = 0;
        uint8 covered = 0;
        for (uint i = 0; i < 5; i++) {
            Signature calldata sig = _signatures[i];
            address recovered = ecrecover(rootsMsgHash, sig.v, sig.r, sig.s);
            if (recovered == validators[j]) {
                covered++;
            }
            j++;
        }
        return covered == 5; 
    }

    function concatRootsAndCreateMessage(
        MerkleProof[] calldata _proofs
    )
        pure
        private
        returns (bytes32)
    {
        bytes memory concatRoots = abi.encode(_proofs[0].root);
        for (uint i = 1; i < _proofs.length; i++) {
            concatRoots = abi.encodePacked(concatRoots, _proofs[i].root);
        }
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(concatRoots)));
    }

    function isContract(
        address _addr
    )
        view
        private
        returns (bool)
    {
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

    // Todo: Consider adding fallback method
    // fallback(
    //     bytes calldata _data
    // )
    //     external
    //     payable
    //     returns (bytes memory)
    // {
    //     if (_data.length != 20) {
    //         revert();
    //     }
    //     address recipientOnNeo = address(bytes20(_data));
    // 
    //     burn(recipientOnNeo);
    // }

    // receive() external payable {
    //     revert();
    // }

    function withdraw(
        address _recipient
    )
        external
        payable
    {
        require((msg.value % (10**10)) == 0, "Only amounts with 8 non-zero decimals allowed for withdrawal");
        require(msg.value >= minWithdrawalAmount, "Smaller than minimum withdrawal amount");
        
        withdrawalNonce++;
        bytes32 withdrawalHash = hashWithdrawal(withdrawalNonce, _recipient, msg.value);
        updateWithdrawalMerkleTree(withdrawalHash);
        emit Withdrawal(withdrawalNonce, _recipient, msg.value);
    }

    function hashWithdrawal(
        uint32 _withdrawalNonce,
        address _recipient,
        uint256 _amount
    )
        pure
        private
        returns (bytes32)
    {
        return sha256(abi.encodePacked(_withdrawalNonce, _recipient, _amount));
    }

    function updateWithdrawalMerkleTree(
        bytes32 _withdrawalHash
    )
        private
        returns (bytes32)
    {
        uint32 max = maxIndex;
        bool carry = true;
        bytes32 right = _withdrawalHash;
        for (uint i = 0; i <= max; i++) {
            bool stored = rootMap[i] != 0x00;
            if (stored) {
                right = computeParentHash(rootMap[i], right);
                if (carry) {
                    delete rootMap[i];
                    if (i == max) {
                        maxIndex += 1;
                        rootMap[maxIndex + 1] = right;
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
    )
        pure
        private
        returns (bytes32)
    {
        return sha256(abi.encodePacked(_left, _right));
    }

    function toEthDecimals(
        uint256 _value
    )
        pure
        private
        returns (uint256)
    {

        return _value * (10**(10));
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Bridge {

    uint32 public maxIndex;
    uint32 public withdrawalNonce;
    uint256 public minWithdrawalAmount;

    mapping(uint256 => bytes32) rootMap;

    // Events

    event Withdrawal(uint _nonce, address _recipientOnNeo, uint _value);

    // Constructor
    constructor (uint256 _minWithdrawalAmount) {
        minWithdrawalAmount = _minWithdrawalAmount;
        // withdrawalNonce default initial value is 0
        // maxIndex default initial value is 0
    }

    // Deposit Verification

    // Todo: Add function to verify root and transfer gas
    // Todo: Introduce limits for # of proofs and max mint amount

    // Withdrawal

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

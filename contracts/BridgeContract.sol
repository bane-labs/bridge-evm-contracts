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
    
    // Bundle smaller variables together to optimize slot usage.
    uint32 public mintNonce;

    uint32 public maxIndex;
    uint32 public withdrawalNonce;

    mapping(uint256 => bytes32) rootMap;

    // Events

    event Withdrawal(uint _nonce, address _recipientOnNeo, uint _value);

    // Deposit Verification

    // Todo: Add function to verify root and transfer gas
    // Todo: Introduce limits for # of proofs and max mint amount

    // Withdrawal

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

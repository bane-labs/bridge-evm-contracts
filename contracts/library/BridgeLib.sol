// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library BridgeLib {
    struct DepositData {
        address payable to;
        uint256 amount;
        uint256 nonce;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // Makes sure the proofs have subsequent nonces.
    function _subsequentNonces(
        DepositData[] calldata _deposits,
        uint256 _startNonce
    ) internal pure returns (bool) {
        uint depositsLength = _deposits.length;
        for (uint8 i = 1; i <= depositsLength; i++) {
            if (_deposits[i - 1].nonce != _startNonce + i) {
                return false;
            }
        }
        return true;
    }

    function _computeNewRoot(
        bytes32 _formerRoot,
        bytes32 _depositHash
    ) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(_formerRoot, _depositHash));
    }

    function _isContract(address _addr) internal view returns (bool) {
        return _addr.code.length > 0;
    }
}

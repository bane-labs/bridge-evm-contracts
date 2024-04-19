// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library BridgeLib {
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

    // Makes sure the proofs have subsequent nonces.
    function _subsequentNonces(
        DepositData[] calldata _deposits,
        uint64 _startNonce
    ) internal pure returns (bool) {
        uint depositsLength = _deposits.length;
        for (uint8 i = 1; i <= depositsLength; i++) {
            if (_deposits[i - 1].nonce != _startNonce + i) {
                return false;
            }
        }
        return true;
    }

    function _computeNewTopRoot(
        bytes32 _previousRoot,
        DepositData[] calldata _deposits
    ) internal pure returns (bytes32) {
        bytes32 parent = _previousRoot;
        uint depositsLength = _deposits.length;
        for (uint i = 0; i < depositsLength; i++) {
            DepositData calldata depositData = _deposits[i];
            bytes32 depositHash = _hashDepositOrWithdrawal(
                depositData.nonce,
                depositData.amount,
                depositData.to
            );
            parent = _computeNewRoot(parent, depositHash);
        }
        return parent;
    }

    function _computeNewRoot(
        bytes32 _formerRoot,
        bytes32 _depositHash
    ) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(_formerRoot, _depositHash));
    }

    function _hashDepositOrWithdrawal(
        uint64 _nonce,
        uint64 _amount,
        address _to
    ) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(_nonce, _amount, _to));
    }

    // Adds 10 decimals to the amount. GasToken originally has 8 decimals and on this chain it has 18 decimals.
    function _addTenDecimals(uint256 _value) internal pure returns (uint256) {
        return uint256(_value) * (10 ** 10);
    }

    // Removes 10 decimal points from the amount. GasToken originally has 8 decimals and on this chain it has 18 decimals.
    function _removeTenDecimals(uint256 _value) internal pure returns (uint64) {
        return uint64(_value / (10 ** 10));
    }

    function _isContract(address _addr) internal view returns (bool) {
        return _addr.code.length > 0;
    }

    function _hasDuplicates(
        address[] calldata _addresses
    ) internal pure returns (bool) {
        uint addressesLength = _addresses.length;
        for (uint i = 0; i < addressesLength - 1; i++) {
            for (uint j = i + 1; j < addressesLength; j++) {
                if (_addresses[i] == _addresses[j]) {
                    return true;
                }
            }
        }
        return false;
    }
}

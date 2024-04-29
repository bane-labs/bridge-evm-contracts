// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library BridgeLib {
    // Types used in storage layout
    struct GasBridge {
        BridgeLib.State depositState;
        BridgeLib.State withdrawalState;
        GasConfig config;
    }

    struct State {
        uint256 nonce;
        bytes32 root;
    }

    struct GasConfig {
        uint256 fee;
        uint256 minAmount;
        uint256 maxAmount;
        uint8 maxDepositsPerDistribution;
        uint256[2] gap;
    }

    struct Claimable {
        address to;
        uint256 amount;
    }

    // Types NOT used in storage layout
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

    function _computeNewTopRoot(
        bytes32 _previousRoot,
        DepositData[] calldata _deposits
    ) internal pure returns (bytes32) {
        bytes32 parent = _previousRoot;
        uint depositsLength = _deposits.length;
        for (uint i = 0; i < depositsLength; i++) {
            DepositData calldata depositData = _deposits[i];
            bytes32 depositHash = BridgeLib._hashDepositOrWithdrawal(
                depositData.nonce,
                depositData.amount,
                depositData.to
            );
            parent = BridgeLib._computeNewRoot(parent, depositHash);
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
        uint256 _nonce,
        uint256 _amount,
        address _to
    ) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(_nonce, _amount, _to));
    }

    // Adds 10 decimals to the amount. GasToken originally has 8 decimals and on this chain it has 18 decimals.
    function _addTenDecimals(uint256 _value) internal pure returns (uint256) {
        return uint256(_value) * (10 ** 10);
    }

    // Removes 10 decimal points from the amount. GasToken originally has 8 decimals and on this chain it has 18 decimals.
    function _removeTenDecimals(
        uint256 _value
    ) internal pure returns (uint256) {
        return uint256(_value / (10 ** 10));
    }

    function _isContract(address _addr) internal view returns (bool) {
        return _addr.code.length > 0;
    }
}

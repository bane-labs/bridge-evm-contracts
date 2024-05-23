// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgeLib.sol";

library GasBridgeLib {
    function _computeNewTopRoot(
        bytes32 _previousRoot,
        BridgeLib.DepositData[] calldata _deposits
    ) internal pure returns (bytes32) {
        bytes32 parent = _previousRoot;
        uint depositsLength = _deposits.length;
        for (uint i = 0; i < depositsLength; i++) {
            BridgeLib.DepositData calldata depositData = _deposits[i];
            bytes32 depositHash = _hashGasBrideOp(
                depositData.nonce,
                depositData.to,
                depositData.amount
            );
            parent = BridgeLib._computeNewRoot(parent, depositHash);
        }
        return parent;
    }

    function _hashGasBrideOp(
        uint256 _nonce,
        address _to,
        uint256 _amount
    ) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(_nonce, _to, _amount));
    }

    // Adds 10 decimals to the amount. GasToken originally has 8 decimals and on this chain it has 18 decimals.
    function _addTenDecimals(uint256 _value) internal pure returns (uint256) {
        return _value * 1e10;
    }

    // Removes 10 decimal points from the amount. GasToken originally has 8 decimals and on this chain it has 18 decimals.
    function _removeTenDecimals(
        uint256 _value
    ) internal pure returns (uint256) {
        return _value / 1e10;
    }
}

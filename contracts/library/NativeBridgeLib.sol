// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BridgeLib} from "./BridgeLib.sol";

library NativeBridgeLib {
    function _computeNewTopRoot(
        bytes32 _previousRoot,
        BridgeLib.DepositData[] calldata _deposits
    )
        internal
        pure
        returns (bytes32)
    {
        bytes32 parent = _previousRoot;
        uint256 depositsLength = _deposits.length;
        for (uint256 i = 0; i < depositsLength; i++) {
            BridgeLib.DepositData calldata depositData = _deposits[i];
            bytes32 depositHash = _hashNativeBrideOp(depositData.nonce, depositData.to, depositData.amount);
            parent = BridgeLib._computeNewRoot(parent, depositHash);
        }
        return parent;
    }

    function _hashNativeBrideOp(uint256 _nonce, address _to, uint256 _amount) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_nonce, _to, _amount));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgeLib.sol";

library TokenBridgeLib {
    function _computeNewTopRootToken(
        bytes32 _previousRoot,
        uint256 _identifier,
        BridgeLib.DepositData[] calldata _deposits
    ) internal pure returns (bytes32) {
        bytes32 parent = _previousRoot;
        uint depositsLength = _deposits.length;
        for (uint i = 0; i < depositsLength; i++) {
            BridgeLib.DepositData calldata depositData = _deposits[i];
            bytes32 depositHash = _hashTokenBridgeOp(
                _identifier,
                depositData.nonce,
                depositData.amount,
                depositData.to
            );
            parent = BridgeLib._computeNewRoot(parent, depositHash);
        }
        return parent;
    }

    /**
     * @dev Hashes the token bridge operation.
     *
     * @param _id The identifier of the token.
     * @param _nonce The nonce of the operation.
     * @param _value The value of the operation.
     * @param _to The address of the recipient.
     */
    function _hashTokenBridgeOp(
        uint256 _id,
        uint256 _nonce,
        uint256 _value,
        address _to
    ) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(_id, _nonce, _value, _to));
    }
}

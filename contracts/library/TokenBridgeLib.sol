// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgeLib.sol";

library TokenBridgeLib {
    /**
     * @dev Hashes every deposit operation and chains it to the previous root. Each deposit data is prepended the
     * token's identifier before it is hashed, such that each hash chain remains exclusive to its corresponding chain
     * and to restrict any replay attack vectors. The final top root is returned.
     *
     * @param _previousRoot the previous top root.
     * @param _id the token identifier.
     * @param _deposits the deposits' data to be hashed and chained.
     */
    function _computeNewTopRoot(
        bytes32 _previousRoot,
        uint256 _id,
        BridgeLib.DepositData[] calldata _deposits
    ) internal pure returns (bytes32) {
        bytes32 parent = _previousRoot;
        uint depositsLength = _deposits.length;
        for (uint i = 0; i < depositsLength; i++) {
            BridgeLib.DepositData calldata depositData = _deposits[i];
            bytes32 depositHash = _hashTokenBridgeOp(
                _id,
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

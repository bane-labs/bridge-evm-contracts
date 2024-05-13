// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgeLib.sol";
import "./StorageTypes.sol";

library TokenBridgeLib {
    /**
     * @dev Hashes every deposit operation and chains it to the previous root. Each deposit data is prepended the
     * token's Neo N3 and Neo X address before it is hashed, such that each token-pair's hash chain remains exclusive
     * to its corresponding chain and to restrict any replay attack vectors. The final top root is returned.
     *
     * @param _previousRoot the previous top root.
     * @param _neoN3Token the address of the token on the Neo N3 network.
     * @param _neoXToken the address of the token on the Neo X network.
     * @param _deposits the deposits' data to be hashed and chained.
     */
    function _computeNewTopRoot(
        bytes32 _previousRoot,
        address _neoN3Token,
        address _neoXToken,
        BridgeLib.DepositData[] calldata _deposits
    ) internal pure returns (bytes32) {
        bytes32 parent = _previousRoot;
        uint depositsLength = _deposits.length;
        for (uint i = 0; i < depositsLength; i++) {
            BridgeLib.DepositData calldata depositData = _deposits[i];
            bytes32 depositHash = _hashTokenBridgeOp(
                _neoN3Token,
                _neoXToken,
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
     * @param _neoN3Token The address of the token on the Neo N3 network.
     * @param _neoXToken The address of the token on the Neo X network.
     * @param _nonce The nonce of the operation.
     * @param _value The value of the operation.
     * @param _to The address of the recipient.
     */
    function _hashTokenBridgeOp(
        address _neoN3Token,
        address _neoXToken,
        uint256 _nonce,
        uint256 _value,
        address _to
    ) internal pure returns (bytes32) {
        return
            sha256(
                abi.encodePacked(_neoN3Token, _neoXToken, _nonce, _value, _to)
            );
    }

    function _isValidConfig(
        StorageTypes.TokenConfig memory _config
    ) internal pure returns (bool) {
        return
            _config.fee > 0 &&
            _config.minAmount > 0 &&
            _config.maxAmount > _config.minAmount &&
            _config.maxDeposits > 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./BridgeLib.sol";
import "./StorageTypes.sol";

library MessageBridgeLib {
    /**
     * @dev Computes a new root hash incorporating a new message operation hash.
     * This function takes the previous root, chains each message operation hash in sequence,
     * and returns the final root.
     *
     * @param _previousRoot The previous message root in the chain
     * @param _messages Array of message data to be hashed and incorporated
     * @return The new root hash after incorporating all message operations
     */
    function _computeNewTopRoot(
        bytes32 _previousRoot,
        StorageTypes.MessageData[] memory _messages
    )
        internal
        pure
        returns (bytes32)
    {
        bytes32 parent = _previousRoot;
        uint256 messagesLength = _messages.length;

        for (uint256 i = 0; i < messagesLength; i++) {
            StorageTypes.MessageData memory messageData = _messages[i];
            bytes32 messageHash = _hashMessageBridgeOp(messageData.nonce, messageData.message);
            parent = BridgeLib._computeNewRoot(parent, messageHash);
        }

        return parent;
    }

    /**
     * @dev Computes the hash of a single message operation.
     * @param _nonce The nonce of the message
     * @param _message The message content
     * @return The hash of the message operation
     */
    function _hashMessageBridgeOp(uint256 _nonce, bytes memory _message) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_nonce, _message));
    }
}

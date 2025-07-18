// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BridgeLib} from "./BridgeLib.sol";
import {StorageTypes} from "./StorageTypes.sol";
import {AMBTypes} from "./AMBTypes.sol";

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
        AMBTypes.MessageData[] memory _messages
    )
        internal
        pure
        returns (bytes32)
    {
        bytes32 parent = _previousRoot;
        uint256 messagesLength = _messages.length;

        for (uint256 i = 0; i < messagesLength; i++) {
            AMBTypes.MessageData memory messageData = _messages[i];
            bytes32 messageHash = _hashMessageBridgeOp(
                messageData.nonce,
                messageData.metadata.version,
                messageData.metadata.sender,
                messageData.metadata.timestamp,
                messageData.message
            );
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
    function _hashMessageBridgeOp(
        uint256 _nonce,
        uint32 _version,
        address _sender,
        uint256 _timestamp,
        bytes memory _message
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_nonce, _version, _sender, _timestamp, _message));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBTypes} from "./AMBTypes.sol";
import {BridgeLib} from "./BridgeLib.sol";

library MessageBridgeLib {
    // 0x735e7a9d
    error UnsupportedMessageType(AMBTypes.MessageType msgType);

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
            bytes32 messageHash =
                _hashMessageBridgeOp(messageData.nonce, messageData.encodedMetadata, messageData.message);
            parent = BridgeLib._computeNewRoot(parent, messageHash);
        }

        return parent;
    }

    /**
     * @dev Computes the hash of a single message operation.
     * @param _nonce The nonce of the message
     * @param _encodedMetadata The encoded metadata of the message
     * @param _rawMessage The message content
     * @return _hash The hash of the message operation
     */
    function _hashMessageBridgeOp(
        uint256 _nonce,
        bytes memory _encodedMetadata,
        bytes memory _rawMessage
    )
        internal
        pure
        returns (bytes32 _hash)
    {
        AMBTypes.MessageType msgType = _readMessageType(_encodedMetadata);
        if (msgType == AMBTypes.MessageType.EXECUTABLE) {
            AMBTypes.MetadataExecutable memory metadata = abi.decode(_encodedMetadata, (AMBTypes.MetadataExecutable));
            _hash = keccak256(
                abi.encodePacked(
                    _nonce, metadata.msgType, metadata.timestamp, metadata.sender, metadata.storeResult, _rawMessage
                )
            );
        } else if (msgType == AMBTypes.MessageType.STORE_ONLY) {
            AMBTypes.MetadataStoreOnly memory metadata = abi.decode(_encodedMetadata, (AMBTypes.MetadataStoreOnly));
            _hash =
                keccak256(abi.encodePacked(_nonce, metadata.msgType, metadata.timestamp, metadata.sender, _rawMessage));
        } else if (msgType == AMBTypes.MessageType.RESULT) {
            AMBTypes.MetadataResult memory metadata = abi.decode(_encodedMetadata, (AMBTypes.MetadataResult));
            _hash = keccak256(
                abi.encodePacked(
                    _nonce,
                    metadata.msgType,
                    metadata.timestamp,
                    metadata.sender,
                    metadata.relatedMessageNonce,
                    _rawMessage
                )
            );
        } else {
            revert UnsupportedMessageType(msgType);
        }
    }

    /**
     * @dev Reads the message type from encoded metadata
     * @param _encodedMetadata The encoded metadata bytes
     * @return msgType The message type enum value
     */
    function _readMessageType(bytes memory _encodedMetadata) internal pure returns (AMBTypes.MessageType msgType) {
        assembly {
            msgType := mload(add(_encodedMetadata, 0x20))
        }
    }
}

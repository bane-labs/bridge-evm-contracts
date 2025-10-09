// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library AMBTypes {
    // DTOs

    struct MessageData {
        uint256 nonce;
        bytes encodedMetadata;
        bytes message;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    struct Call {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    enum MessageType {
        EXECUTABLE, // The message is executable
        STORE_ONLY, // The message is only stored. It cannot is not executable.
        RESULT // The message is a result of a message execution.

    }

    struct MetadataExecutable {
        // Slot 1
        MessageType msgType; // 1 byte
        bool storeResult; // 1 byte
        address sender; // 20 bytes
        // bytes remaining in slot 1 (10 bytes)
        // Slot 2
        uint256 timestamp;
    }

    struct MetadataStoreOnly {
        // Slot 1
        MessageType msgType; // 1 byte
        address sender; // 20 bytes
        // bytes remaining in slot 1 (11 bytes)
        // Slot 2
        uint256 timestamp;
    }

    struct MetadataResult {
        // Slot 1
        MessageType msgType; // 1 byte
        address sender; // 20 bytes
        // bytes remaining in slot 1 (11 bytes)
        // Slot 2
        uint256 timestamp;
        // Slot 3
        uint256 relatedMessageNonce; // The nonce of the message that this result is related to
    }
}

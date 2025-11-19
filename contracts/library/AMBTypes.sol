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
        MessageType msgType;
        uint256 timestamp;
        address sender;
        bool storeResult;
    }

    struct MetadataStoreOnly {
        MessageType msgType;
        uint256 timestamp;
        address sender;
    }

    struct MetadataResult {
        MessageType msgType;
        uint256 timestamp;
        address sender;
        uint256 relatedMessageNonce; // The nonce of the message that this result is related to
    }
}

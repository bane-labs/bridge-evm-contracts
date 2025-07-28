// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {StorageTypes} from "./StorageTypes.sol";

library AMBTypes {
    struct MessageBridgeConfig {
        bool isSet;
        bool paused;
        uint256 fee;
        uint256 maxMessageSize;
        uint256 maxNrMessages;
    }

    struct MessageBridgeState {
        bool paused;
        StorageTypes.State n3ToEvmState;
        StorageTypes.State evmToN3State;
        MessageConfig config;
    }

    struct MessageConfig {
        uint256 fee;
        uint256 maxMessageSize;
        uint256 maxNrMessages;
        uint256 executionWindowSeconds; // Window of time a message can be executed after it was stored
    }

    struct MessageData {
        uint256 nonce;
        Metadata metadata;
        bytes message;
    }

    struct Metadata {
        uint32 version; // For forward compatibility, should be incremented if the structure changes
        address sender;
        uint256 timestamp;
    }

    struct StoredMessage {
        Metadata metadata;
        bytes message;
        bool executed;
    }

    struct Call {
        bool allowFailure;
        bool requiresResponse; // The user can specify if the call requires a response to be sent back across the bridge.
        address target;
        uint256 value;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    struct SendMessageData {
        uint256 nonce;
        bytes encodedMetadata;
        bytes message;
    }

    enum SendMessageType {
        EXECUTABLE, // The message is executable
        STORE_ONLY, // The message is only stored. It cannot is not executable.
        RESULT // The message is a result of a message execution.

    }

    struct SendMetadataExecutable {
        SendMessageType msgType;
        uint256 timestamp;
        address sender;
        bool storeResult;
    }

    struct SendMetadataStoreOnly {
        SendMessageType msgType;
        uint256 timestamp;
        address sender;
    }

    struct SendMetadataResult {
        SendMessageType msgType;
        uint256 timestamp;
        address sender;
        uint256 relatedMessageNonce; // The nonce of the message that this result is related to
    }
}

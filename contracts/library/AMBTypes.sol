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
        bytes encodedMetadata;
        bytes message;
    }

    struct StoredMessage {
        bytes encodedMetadata;
        bytes message;
        bool executed;
    }

    struct Call {
        address target;
        bool allowFailure;
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

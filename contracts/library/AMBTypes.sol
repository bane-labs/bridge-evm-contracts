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
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IBridgeManagement} from "../interfaces/IBridgeManagement.sol";
import {IExecutionManager} from "../messageBridge/interfaces/IExecutionManager.sol";
import {StorageTypes} from "./StorageTypes.sol";

library AMBStorage {
    //keccak256(abi.encode(uint256(keccak256("AMB.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AMBStorageLocation = 0xd6595d2280e6cba67baf67ff997445e733b244161e59228efeb7032069381100;

    /// @custom:storage-location erc7201:AMB.storage
    struct AMB {
        IBridgeManagement management;
        IExecutionManager messageExecutionManager;
        MessageBridgeState messageBridgeState;
        uint256 unclaimedFees;
        mapping(uint256 => StoredMessage) n3ToEvmMessages;
        mapping(uint256 => bytes) n3ToEvmExecutionResults;
        mapping(uint256 => ExecutableState) n3ToEvmExecutableStates;
    }

    struct MessageBridgeState {
        bool paused;
        bool sendingPaused;
        bool executingPaused;
        StorageTypes.State n3ToEvmState;
        StorageTypes.State evmToN3State;
        MessageConfig config;
    }

    struct StoredMessage {
        bytes encodedMetadata;
        bytes message;
    }

    struct MessageConfig {
        uint256 fee;
        uint256 maxMessageSize;
        uint256 maxNrMessages;
        uint256 executionWindowSeconds; // Window of time a message can be executed after it was stored
    }

    struct ExecutableState {
        bool executed;
        uint256 expirationTimestamp;
    }

    function get() internal pure returns (AMB storage $) {
        assembly {
            $.slot := AMBStorageLocation
        }
    }

    function getConfig() internal view returns (AMBStorage.MessageConfig memory config) {
        return AMBStorage.get().messageBridgeState.config;
    }
}

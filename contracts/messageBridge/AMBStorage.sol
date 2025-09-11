// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IBridgeManagement} from "../interfaces/IBridgeManagement.sol";
import {IExecutionManager} from "../messageBridge/interfaces/IExecutionManager.sol";
import {StorageTypes} from "../library/StorageTypes.sol";

abstract contract AMBStorage {
    //keccak256(abi.encode(uint256(keccak256("AMB.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AMBStorageLocation = 0xd6595d2280e6cba67baf67ff997445e733b244161e59228efeb7032069381100;

    /// @custom:storage-location erc7201:AMB.storage
    struct AMB {
        IBridgeManagement management;
        IExecutionManager messageExecutionManager;
        MessageBridgeState messageBridgeState;
        uint256 unclaimedFees;
        mapping(uint256 => StoredMessage) evmMessages;
        mapping(uint256 => bytes) evmExecutionResults;
        mapping(uint256 => ExecutableState) evmExecutableStates;
    }

    struct MessageBridgeState {
        bool paused;
        bool sendingPaused;
        bool executingPaused;
        StorageTypes.State evmState;
        StorageTypes.State n3State;
        MessageConfig config;
    }

    struct StoredMessage {
        bytes encodedMetadata;
        bytes rawMessage;
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

    function getManagement() external view returns (IBridgeManagement) {
        return getStorage().management;
    }

    function getMessageExecutionManager() external view returns (IExecutionManager) {
        return getStorage().messageExecutionManager;
    }

    function getMessageBridgeState() external view returns (MessageBridgeState memory) {
        return getStorage().messageBridgeState;
    }

    function getUnclaimedFees() external view returns (uint256) {
        return getStorage().unclaimedFees;
    }

    function getEvmMessage(uint256 messageId) external view returns (StoredMessage memory) {
        return getStorage().evmMessages[messageId];
    }

    function getEvmExecutionResult(uint256 messageId) external view returns (bytes memory) {
        return getStorage().evmExecutionResults[messageId];
    }

    function getEvmExecutableState(uint256 messageId) external view returns (ExecutableState memory) {
        return getStorage().evmExecutableStates[messageId];
    }

    function getStorage() internal pure returns (AMB storage $) {
        assembly {
            $.slot := AMBStorageLocation
        }
    }

    function getConfig() internal view returns (MessageConfig memory config) {
        return getStorage().messageBridgeState.config;
    }
}

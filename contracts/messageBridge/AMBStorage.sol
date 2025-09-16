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
        mapping(uint256 => uint256) executableNonceToN3ResultNonce;
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

    function management() public view returns (IBridgeManagement) {
        return getStorage().management;
    }

    function executionManager() public view returns (IExecutionManager) {
        return getStorage().messageExecutionManager;
    }

    function messageBridgeState() external view returns (MessageBridgeState memory) {
        return getStorage().messageBridgeState;
    }

    function unclaimedFees() external view returns (uint256) {
        return getStorage().unclaimedFees;
    }

    function getEvmMessage(uint256 nonce) public view returns (StoredMessage memory) {
        return getStorage().evmMessages[nonce];
    }

    function getEvmExecutionResult(uint256 nonce) public view returns (bytes memory) {
        return getStorage().evmExecutionResults[nonce];
    }

    function getEvmExecutableState(uint256 nonce) public view returns (ExecutableState memory) {
        return getStorage().evmExecutableStates[nonce];
    }

    function getN3ResultNonce(uint256 relatedMessageNonce) public view returns (uint256) {
        return getStorage().executableNonceToN3ResultNonce[relatedMessageNonce];
    }

    // Message Bridge state getters
    function evmState() public view returns (StorageTypes.State memory) {
        return getStorage().messageBridgeState.evmState;
    }

    function n3State() public view returns (StorageTypes.State memory) {
        return getStorage().messageBridgeState.n3State;
    }

    // Public config getters (also used internally)
    function messageBridgePaused() public view returns (bool) {
        return getStorage().messageBridgeState.paused;
    }

    function sendingPaused() public view returns (bool) {
        return getStorage().messageBridgeState.sendingPaused;
    }

    function executingPaused() public view returns (bool) {
        return getStorage().messageBridgeState.executingPaused;
    }

    function sendingFee() public view returns (uint256) {
        return getStorage().messageBridgeState.config.fee;
    }

    function maxMessageSize() public view returns (uint256) {
        return getStorage().messageBridgeState.config.maxMessageSize;
    }

    function maxNrMessages() public view returns (uint256) {
        return getStorage().messageBridgeState.config.maxNrMessages;
    }

    function executionWindowSeconds() public view returns (uint256) {
        return getStorage().messageBridgeState.config.executionWindowSeconds;
    }

    /**
     * @notice Returns the storage struct located at the predefined storage slot.
     * @dev This should be used only for writing to the storage. For reading, use the individual getters.
     * @return $ The storage struct.
     */
    function getStorage() internal pure returns (AMB storage $) {
        assembly {
            $.slot := AMBStorageLocation
        }
    }
}

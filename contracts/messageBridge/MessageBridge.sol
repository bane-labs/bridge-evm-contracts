// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBStorage} from "./AMBStorage.sol";
import {AMBTypes} from "../library/AMBTypes.sol";
import {BridgeLib} from "../library/BridgeLib.sol";
import {IBridgeManagement} from "../interfaces/IBridgeManagement.sol";
import {IExecutionManager} from "./interfaces/IExecutionManager.sol";
import {IMessageBridge} from "./interfaces/IMessageBridge.sol";
import {MessageBridgeLib} from "../library/MessageBridgeLib.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {StorageTypes} from "../library/StorageTypes.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:oz-upgrades-unsafe-allow missing-initializer
contract MessageBridge is IMessageBridge, ReentrancyGuardUpgradeable, UUPSUpgradeable, AMBStorage {
    address public constant GOV_ADMIN = 0x1212000000000000000000000000000000000000;

    uint32 public constant VERSION = 1;

    constructor() {
        _disableInitializers();
    }

    //0x79828e03
    error NoAuthorization();
    //0x58d620b3
    error InvalidFee();
    //0xaa7feadc
    error InvalidValue();
    //0xd7c2b571
    error InvalidNonceSequence();
    //0x504570e3
    error InvalidRoot();
    //0xc48c8e48
    error InvalidValidatorSignatures();
    //0x3a617a54
    error UnauthorizedUpgrade();
    //0x03290dc9
    error MessageNotFound(uint256 nonce);
    //0x25ecb492
    error ResultNotFound(uint256 nonce);
    //0xa4c897b0
    error MessageBridgePaused();
    //0xfa5fc19e
    error MessageBridgeNotPaused();
    //0x56a6145d
    error SendingPaused();
    //0x26e7ced5
    error SendingNotPaused();
    //0xf4700efc
    error ExecutingPaused();
    //0x61654835
    error ExecutingNotPaused();
    //0xd221f922
    error ExecutionManagerNotSet();
    //0x2ad81d67
    error MessageAlreadyExecuted(uint256 nonce);
    //0x60744242
    error NoMessages();
    //0x1ec0b2f7
    error TooManyMessages();
    //0xee3675d4
    error NotGovernor();
    //0xc64891a5
    error NotRelayer();
    //0x1ef8664b
    error ExecutionWindowExpired(uint256 expiry, uint256 currentTime);
    //0xa1bbcb21
    error MessageTooLarge(uint256 maxSize, uint256 provided);
    //0xa458261b
    error InsufficientFee(uint256 minExpected, uint256 provided);
    //0x038d5f7b
    error ExactFeeRequired(uint256 feeExpected, uint256 feeProvided);
    //0x90b8ec18
    error TransferFailed();

    function pause() external override onlyGovernorOrSecurityGuard whenNotPaused {
        getStorage().messageBridgeState.paused = true;
        emit Pause();
    }

    function unpause() external override onlyGovernor whenPaused {
        getStorage().messageBridgeState.paused = false;
        emit Unpause();
    }

    function pauseSending() external override onlyGovernorOrSecurityGuard whenSendingNotPaused {
        getStorage().messageBridgeState.sendingPaused = true;
        emit SendingPause();
    }

    function unpauseSending() external override onlyGovernor whenSendingPaused {
        getStorage().messageBridgeState.sendingPaused = false;
        emit SendingUnpause();
    }

    function pauseExecuting() external override onlyGovernorOrSecurityGuard whenExecutingNotPaused {
        getStorage().messageBridgeState.executingPaused = true;
        emit ExecutingPause();
    }

    function unpauseExecuting() external override onlyGovernor whenExecutingPaused {
        getStorage().messageBridgeState.executingPaused = false;
        emit ExecutingUnpause();
    }

    /**
     * @notice Gets the executable state of a message by its nonce.
     * @param nonce The nonce of the message.
     * @return executableState The state of the executable message.
     * @dev Reverts if the message does not exist or is not of type EXECUTABLE.
     */
    function getExecutableState(uint256 nonce)
        public
        view
        override
        returns (AMBStorage.ExecutableState memory executableState)
    {
        // Check if the message exists
        AMBStorage.StoredMessage memory storedMessage = getEvmMessage(nonce);
        bytes memory rawMessage = storedMessage.rawMessage;
        if (rawMessage.length == 0) revert MessageNotFound(nonce);

        // Check if the message is of type EXECUTABLE
        bytes memory encodedMetadata = storedMessage.encodedMetadata;
        AMBTypes.MessageType msgType = MessageBridgeLib._readMessageType(encodedMetadata);
        if (msgType != AMBTypes.MessageType.EXECUTABLE) revert MessageBridgeLib.UnsupportedMessageType(msgType);

        executableState = getEvmExecutableState(nonce);
    }

    /**
     * @notice Sends an executable message to the Neo N3 blockchain.
     * @param _message The message to be sent.
     * @param _storeResult Whether to store the result of the message execution.
     */
    function sendExecutableMessage(
        bytes calldata _message,
        bool _storeResult
    )
        external
        payable
        whenNotPaused
        whenSendingNotPaused
        returns (uint256 nonce)
    {
        AMBTypes.MetadataExecutable memory metadata = AMBTypes.MetadataExecutable({
            msgType: AMBTypes.MessageType.EXECUTABLE,
            timestamp: block.timestamp,
            sender: msg.sender,
            storeResult: _storeResult
        });
        bytes memory encodedMetadata = abi.encode(metadata);
        nonce = _sendMessageWithMetadata(_message, encodedMetadata);
    }

    /**
     * @notice Sends a store-only message to the Neo N3 blockchain.
     * @param _message The message to be sent.
     */
    function sendMessage(bytes calldata _message)
        external
        payable
        whenNotPaused
        whenSendingNotPaused
        returns (uint256 nonce)
    {
        AMBTypes.MetadataStoreOnly memory metadata = AMBTypes.MetadataStoreOnly({
            msgType: AMBTypes.MessageType.STORE_ONLY,
            timestamp: block.timestamp,
            sender: msg.sender
        });
        bytes memory encodedMetadata = abi.encode(metadata);
        nonce = _sendMessageWithMetadata(_message, encodedMetadata);
    }

    /**
     * @notice Sends a result message for a previously executed message.
     * @param _relatedMessageNonce The nonce of the related message that was executed.
     */
    function sendResultMessage(uint256 _relatedMessageNonce)
        external
        payable
        whenNotPaused
        whenSendingNotPaused
        returns (uint256 nonce)
    {
        // Check if the message exists by checking if it has content
        if (getEvmMessage(_relatedMessageNonce).rawMessage.length == 0) {
            revert MessageNotFound(_relatedMessageNonce);
        }

        bytes memory resultMessage = getEvmExecutionResult(_relatedMessageNonce);
        // Check if a result was stored for this message
        if (resultMessage.length == 0) revert ResultNotFound(_relatedMessageNonce);

        AMBTypes.MetadataResult memory metadata = AMBTypes.MetadataResult({
            msgType: AMBTypes.MessageType.RESULT,
            timestamp: block.timestamp,
            sender: msg.sender,
            relatedMessageNonce: _relatedMessageNonce
        });
        bytes memory encodedMetadata = abi.encode(metadata);

        nonce = _sendMessageWithMetadata(resultMessage, encodedMetadata);
    }

    /**
     * @notice Gets the result message for a previously executed message.
     * @param relatedMessageNonce The nonce of the related message that was executed.
     * @return result The result of the message execution.
     */
    function getResult(uint256 relatedMessageNonce) external view returns (AMBTypes.Result memory result) {
        if (getEvmMessage(relatedMessageNonce).rawMessage.length == 0) {
            revert MessageNotFound(relatedMessageNonce);
        }
        bytes memory message = getEvmExecutionResult(relatedMessageNonce);
        if (message.length == 0) revert ResultNotFound(relatedMessageNonce);
        return abi.decode(message, (AMBTypes.Result));
    }

    /**
     * @notice Gets the raw result message for a previously executed message.
     * @param relatedMessageNonce The nonce of the related message that was executed.
     * @return result The raw result message bytes.
     */
    function getN3Result(uint256 relatedMessageNonce) external view returns (bytes memory) {
        uint256 resultNonce = getN3ResultNonce(relatedMessageNonce);
        if (resultNonce == 0) return new bytes(0); // No result message was sent to N3 so we return empty bytes
        return getEvmMessage(resultNonce).rawMessage;
    }

    function _sendMessageWithMetadata(
        bytes memory _message,
        bytes memory _encodedMetadata
    )
        private
        returns (uint256 nonce)
    {
        uint256 maxSize = maxMessageSize();
        // Check message size against max allowed size
        if (_message.length > maxSize) revert MessageTooLarge(maxSize, _message.length);

        // Process the fee for message sending
        address from = msg.sender;
        _captureFeeAndRefundExcessToEOA(from, msg.value, sendingFee());

        // Compute the new root and update the message state
        StorageTypes.State memory state = n3State();
        nonce = state.nonce + 1;

        // Create message hash
        bytes32 messageHash = MessageBridgeLib._hashMessageBridgeOp(nonce, _encodedMetadata, _message);

        // Compute new root
        bytes32 newRoot = BridgeLib._computeNewRoot(state.root, messageHash);

        // Update the state
        getStorage().messageBridgeState.n3State = StorageTypes.State({nonce: nonce, root: newRoot});

        // Emit event with all relevant information
        emit MessageSend(nonce, from, _encodedMetadata, _message, messageHash, newRoot);
    }

    /**
     * @notice Stores messages sent from the Neo N3 blockchain.
     * @param _evmRoot The root of the EVM hash chain.
     * @param _signatures The signatures of the validators.
     * @param _messages The messages to be stored.
     */
    function storeMessages(
        bytes32 _evmRoot,
        BridgeLib.Signature[] calldata _signatures,
        AMBTypes.MessageData[] calldata _messages
    )
        external
        override
        onlyRelayer
        whenNotPaused
        nonReentrant
    {
        // Check parameter validity
        uint256 messageLength = _messages.length;
        if (messageLength == 0) revert NoMessages();

        StorageTypes.State memory state = evmState();

        if (messageLength > maxNrMessages()) revert TooManyMessages();

        // Check if nonces are in sequence
        // More gas-efficient nonce validation that doesn't update a variable on each iteration
        // Each nonce should be exactly (state.nonce + position in array + 1)
        for (uint256 i = 0; i < messageLength; i++) {
            if (_messages[i].nonce != state.nonce + i + 1) revert InvalidNonceSequence();
        }

        // Validate that the provided message deposit root is equal to the computed root
        if (MessageBridgeLib._computeNewTopRoot(state.root, _messages) != _evmRoot) revert InvalidRoot();

        // Verify that the provided signatures are valid
        if (!management().verifyValidatorSignatures(_evmRoot, _signatures)) {
            revert InvalidValidatorSignatures();
        }

        // Update the message bridge deposit state
        getStorage().messageBridgeState.evmState =
            StorageTypes.State({nonce: _messages[messageLength - 1].nonce, root: _evmRoot});
        emit EvmRootUpdate(_messages[messageLength - 1].nonce, _evmRoot);

        // Store messages
        for (uint256 i = 0; i < messageLength; i++) {
            _storeMessage(_messages[i]);
        }
    }

    /**
     * @notice Store a message in the bridge storage.
     * @param messageData the data of the message to be stored.
     */
    function _storeMessage(AMBTypes.MessageData memory messageData) private {
        getStorage().evmMessages[messageData.nonce] =
            StoredMessage({encodedMetadata: messageData.encodedMetadata, rawMessage: messageData.message});

        _saveAdditionalState(messageData.nonce, messageData.encodedMetadata);

        emit Store(messageData.nonce, messageData.message);
    }

    function _saveAdditionalState(uint256 nonce, bytes memory encodedMetadata) private {
        AMBTypes.MessageType msgType = MessageBridgeLib._readMessageType(encodedMetadata);
        if (msgType == AMBTypes.MessageType.EXECUTABLE) {
            uint256 window = executionWindowSeconds();
            // Use the block timestamp to set the expiration timestamp for the executable message
            // in case the relayer is down and does not relay the message in time.
            getStorage().evmExecutableStates[nonce] =
                ExecutableState({executed: false, expirationTimestamp: block.timestamp + window});
        } else if (msgType == AMBTypes.MessageType.RESULT) {
            AMBTypes.MetadataResult memory metadata = abi.decode(encodedMetadata, (AMBTypes.MetadataResult));
            getStorage().executableNonceToN3ResultNonce[metadata.relatedMessageNonce] = nonce;
        }
    }

    /**
     * @notice Executes a message that was sent from the Neo N3 blockchain.
     * @param nonce The nonce of the message to be executed.
     * @return result The result of the message execution.
     */
    function executeMessage(uint256 nonce)
        external
        payable
        nonReentrant
        whenExecutingNotPaused
        returns (AMBTypes.Result memory)
    {
        // Check if the execution manager is set
        IExecutionManager execManager = executionManager();
        if (address(execManager) == address(0)) revert ExecutionManagerNotSet();

        // Check if the message was already executed
        AMBStorage.ExecutableState memory executableState = getExecutableState(nonce);
        if (executableState.executed) revert MessageAlreadyExecuted(nonce);

        // Check if the message execution window has expired
        if (block.timestamp > executableState.expirationTimestamp) {
            revert ExecutionWindowExpired(executableState.expirationTimestamp, block.timestamp);
        }
        // Mark as executed to avoid reentrancy issues

        getStorage().evmExecutableStates[nonce].executed = true;

        // Execute the message using the execution manager
        AMBTypes.Result memory result = execManager.executeMessage{value: msg.value}(
            nonce, getEvmMessage(nonce).rawMessage, payable(msg.sender)
        );

        // Store encode response and emit event
        AMBTypes.MetadataExecutable memory metadata =
            abi.decode(getEvmMessage(nonce).encodedMetadata, (AMBTypes.MetadataExecutable));
        if (metadata.storeResult) getStorage().evmExecutionResults[nonce] = abi.encode(result);
        emit MessageExecuted(nonce, result);

        return result;
    }

    function setSendingFee(uint256 _fee) external override onlyGovernor {
        if (_fee == 0) revert InvalidFee();
        getStorage().messageBridgeState.config.fee = _fee;
        emit SendingFeeChange(_fee);
    }

    function setMaxMessageSize(uint256 _maxSize) external override onlyGovernor {
        if (_maxSize == 0) revert InvalidValue();
        getStorage().messageBridgeState.config.maxMessageSize = _maxSize;
        emit MaxMessageSizeChange(_maxSize);
    }

    function setMaxNrMessages(uint256 _maxNrMessages) external override onlyGovernor {
        if (_maxNrMessages == 0) revert InvalidValue();
        getStorage().messageBridgeState.config.maxNrMessages = _maxNrMessages;
        emit MaxNrMessagesChange(_maxNrMessages);
    }

    function setExecutionManager(address _executor) external override onlyGovernor {
        getStorage().messageExecutionManager = IExecutionManager(_executor);
        emit ExecutionManagerChange(_executor);
    }

    function setExecutionWindowSeconds(uint256 windowSeconds) external override onlyGovernor {
        if (windowSeconds == 0) revert InvalidValue();
        getStorage().messageBridgeState.config.executionWindowSeconds = windowSeconds;
        emit MessageExecutionWindowChange(windowSeconds);
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyAdmin {}

    // Modifiers

    modifier onlyAdmin() {
        if (msg.sender != GOV_ADMIN) revert UnauthorizedUpgrade();
        _;
    }

    modifier onlyRelayer() {
        if (msg.sender != management().getRelayer()) revert NotRelayer();
        _;
    }

    modifier onlyGovernor() {
        if (msg.sender != management().getGovernor()) revert NotGovernor();
        _;
    }

    modifier onlyGovernorOrSecurityGuard() {
        if (msg.sender != management().getGovernor() && msg.sender != management().getSecurityGuard()) {
            revert NoAuthorization();
        }
        _;
    }

    modifier whenNotPaused() {
        if (messageBridgePaused()) revert MessageBridgePaused();
        _;
    }

    modifier whenPaused() {
        if (!messageBridgePaused()) revert MessageBridgeNotPaused();
        _;
    }

    modifier whenSendingNotPaused() {
        if (sendingPaused()) revert SendingPaused();
        _;
    }

    modifier whenSendingPaused() {
        if (!sendingPaused()) revert SendingNotPaused();
        _;
    }

    modifier whenExecutingNotPaused() {
        if (executingPaused()) revert ExecutingPaused();
        _;
    }

    modifier whenExecutingPaused() {
        if (!executingPaused()) revert ExecutingNotPaused();
        _;
    }

    /**
     * @dev Checks the provided value against the required fee. If the provided value exceeds the required fee, the
     * excess amount is refunded if the sender is an EOA. Otherwise, if the sender is a contract, it is reverted.
     * @param _from the sender.
     * @param _msgValue the value sent with the transaction.
     * @param _fee the required fee.
     */
    function _captureFeeAndRefundExcessToEOA(address _from, uint256 _msgValue, uint256 _fee) private {
        // Revert if the provided value is lower than the required fee.
        if (_msgValue < _fee) revert InsufficientFee(_fee, _msgValue);
        // Refund the sender (only EOAs) if the provided value is higher than the required fee.
        if (_msgValue > _fee) {
            // Revert if the sender is a contract.
            if (BridgeLib._isContract(_from)) revert ExactFeeRequired(_fee, _msgValue);
            (bool success,) = payable(_from).call{value: _msgValue - _fee}("");
            if (!success) revert TransferFailed();
        }
        getStorage().unclaimedFees += _fee;
    }
}

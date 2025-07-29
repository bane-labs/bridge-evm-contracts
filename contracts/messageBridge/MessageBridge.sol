// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IBridgeManagement} from "../interfaces/IBridgeManagement.sol";
import {AMBTypes} from "../library/AMBTypes.sol";
import {BridgeLib} from "../library/BridgeLib.sol";
import {MessageBridgeLib} from "../library/MessageBridgeLib.sol";
import {StorageTypes} from "../library/StorageTypes.sol";
import {IExecutionManager} from "./interfaces/IExecutionManager.sol";
import {IMessageBridge} from "./interfaces/IMessageBridge.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract MessageBridge is IMessageBridge, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    address public constant GOV_ADMIN = 0x1212000000000000000000000000000000000000;

    //keccak256(abi.encode(uint256(keccak256("AMB.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AMBStorageLocation = 0xd6595d2280e6cba67baf67ff997445e733b244161e59228efeb7032069381100;

    uint32 public constant VERSION = 1;

    /// @custom:storage-location erc7201:AMB.storage
    struct AMBStorage {
        IBridgeManagement management;
        bool sendingPaused;
        bool executingPaused;
        uint256 unclaimedRewards;
        AMBTypes.MessageBridgeState messageBridgeState;
        mapping(uint256 => AMBTypes.StoredMessage) n3ToEvmMessages;
        mapping(uint256 => AMBTypes.Result) n3ToEvmExecutionResults;
        IExecutionManager messageExecutionManager;
    }

    function _getAMBStorage() internal pure returns (AMBStorage storage $) {
        assembly {
            $.slot := AMBStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _management,
        uint256 _fee,
        uint256 _maxMessageSize,
        uint256 _maxNrMessages,
        uint256 _executionWindowSeconds
    )
        external
        virtual
        initializer
        onlyAdmin
    {
        __ReentrancyGuard_init();
        _getAMBStorage().management = IBridgeManagement(_management);
        _setMessageBridge(_fee, _maxMessageSize, _maxNrMessages, _executionWindowSeconds);
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
    //0x774249f8
    error MessageBridgeNotSet();
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
    //0x018e5d6a
    error InvalidMessageSize();
    //0x000bf7e9
    error MessageRootMismatch();
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

    function messageBridgeIsSet() external view override returns (bool) {
        return _messageBridgeIsSet();
    }

    function pauseMessageBridge()
        external
        override
        onlyGovernorOrSecurityGuard
        onlyIfMessageBridgeSet
        whenMessageBridgeNotPaused
    {
        _pauseMessageBridge();
        emit MessageBridgePause();
    }

    function unpauseMessageBridge() external override onlyGovernor onlyIfMessageBridgeSet whenMessageBridgePaused {
        _unpauseMessageBridge();
        emit MessageBridgeUnpause();
    }

    function isMessageBridgePaused() external view override returns (bool) {
        return _getAMBStorage().messageBridgeState.paused;
    }

    function pauseSending() external override onlyGovernorOrSecurityGuard whenSendingNotPaused {
        _getAMBStorage().sendingPaused = true;
        emit SendingPause();
    }

    function unpauseSending() external override onlyGovernor whenSendingPaused {
        _getAMBStorage().sendingPaused = false;
        emit SendingUnpause();
    }

    function isSendingPaused() external view override returns (bool) {
        return _getAMBStorage().sendingPaused;
    }

    function pauseExecuting() external override onlyGovernorOrSecurityGuard whenExecutingNotPaused {
        _getAMBStorage().executingPaused = true;
        emit ExecutingPause();
    }

    function unpauseExecuting() external override onlyGovernor whenExecutingPaused {
        _getAMBStorage().executingPaused = false;
        emit ExecutingUnpause();
    }

    function isExecutingPaused() external view override returns (bool) {
        return _getAMBStorage().executingPaused;
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
        onlyIfMessageBridgeSet
        whenMessageBridgeNotPaused
        whenSendingNotPaused
    {
        AMBTypes.MetadataExecutable memory metadata = AMBTypes.MetadataExecutable({
            msgType: AMBTypes.MessageType.EXECUTABLE,
            timestamp: block.timestamp,
            sender: msg.sender,
            storeResult: _storeResult
        });
        bytes memory encodedMetadata = abi.encode(metadata);
        _sendMessageWithMetadata(_message, encodedMetadata);
    }

    /**
     * @notice Sends a store-only message to the Neo N3 blockchain.
     * @param _message The message to be sent.
     */
    function sendMessage(bytes calldata _message)
        external
        payable
        onlyIfMessageBridgeSet
        whenMessageBridgeNotPaused
        whenSendingNotPaused
    {
        AMBTypes.MetadataStoreOnly memory metadata = AMBTypes.MetadataStoreOnly({
            msgType: AMBTypes.MessageType.STORE_ONLY,
            timestamp: block.timestamp,
            sender: msg.sender
        });
        bytes memory encodedMetadata = abi.encode(metadata);
        _sendMessageWithMetadata(_message, encodedMetadata);
    }

    function sendResultMessage(uint256 _relatedMessageNonce)
        external
        payable
        onlyIfMessageBridgeSet
        whenMessageBridgeNotPaused
        whenSendingNotPaused
    {
        AMBStorage storage ambStorage = _getAMBStorage();

        // Check if the message exists by checking if it has content
        if (ambStorage.n3ToEvmMessages[_relatedMessageNonce].message.length == 0) {
            revert MessageNotFound(_relatedMessageNonce);
        }

        bytes memory message = ambStorage.n3ToEvmExecutionResults[_relatedMessageNonce].returnData;
        // Check if a result was stored for this message
        if (message.length == 0) revert ResultNotFound(_relatedMessageNonce);

        AMBTypes.MetadataResult memory metadata = AMBTypes.MetadataResult({
            msgType: AMBTypes.MessageType.RESULT,
            timestamp: block.timestamp,
            sender: msg.sender,
            relatedMessageNonce: _relatedMessageNonce
        });
        bytes memory encodedMetadata = abi.encode(metadata);

        _sendMessageWithMetadata(message, encodedMetadata);
    }

    function _sendMessageWithMetadata(bytes memory _message, bytes memory _encodedMetadata) private {
        AMBTypes.MessageConfig memory config = _getMessageBridgeConfig();

        // Check message size against max allowed size
        if (_message.length > config.maxMessageSize) revert MessageTooLarge(config.maxMessageSize, _message.length);

        // Process the fee for message sending
        address from = msg.sender;
        _processBridgeFee(from, msg.value, config.fee);

        // Compute the new root and update the message state
        StorageTypes.State memory state = _getMessageBridgeEvmToN3State();
        uint256 newNonce = state.nonce + 1;

        // Create message hash
        bytes32 messageHash = MessageBridgeLib._hashMessageBridgeOp(newNonce, _encodedMetadata, _message);

        // Compute new root
        bytes32 newRoot = BridgeLib._computeNewRoot(state.root, messageHash);

        // Update the state
        _setMessageBridgeEvmToN3State(StorageTypes.State({nonce: newNonce, root: newRoot}));

        // Emit event with all relevant information
        emit MessageSent(newNonce, _message, block.timestamp, from, messageHash, newRoot);
    }

    function storeMessage(
        bytes32 _depositRoot,
        BridgeLib.Signature[] calldata _signatures,
        AMBTypes.MessageData[] calldata _messages
    )
        external
        override
        onlyRelayer
        onlyIfMessageBridgeSet
        whenMessageBridgeNotPaused
        nonReentrant
    {
        // Check parameter validity
        uint256 messageLength = _messages.length;
        if (messageLength == 0) revert NoMessages();

        StorageTypes.State memory state = _getMessageBridgeN3ToEvmState();
        AMBTypes.MessageConfig memory config = _getMessageBridgeConfig();

        if (messageLength > config.maxNrMessages) revert TooManyMessages();

        // Check if nonces are in sequence
        // More gas-efficient nonce validation that doesn't update a variable on each iteration
        // Each nonce should be exactly (state.nonce + position in array + 1)
        for (uint256 i = 0; i < messageLength; i++) {
            if (_messages[i].nonce != state.nonce + i + 1) revert InvalidNonceSequence();
        }

        // Validate that the provided message deposit root is equal to the computed root
        if (MessageBridgeLib._computeNewTopRoot(state.root, _messages) != _depositRoot) revert InvalidRoot();

        // Verify that the provided signatures are valid
        if (!_getAMBStorage().management.verifyValidatorSignatures(_depositRoot, _signatures)) {
            revert InvalidValidatorSignatures();
        }

        // Update the message bridge deposit state
        _setMessageBridgeN3ToEvmState(
            StorageTypes.State({nonce: _messages[messageLength - 1].nonce, root: _depositRoot})
        );
        emit MessageDepositRootUpdate(_messages[messageLength - 1].nonce, _depositRoot);

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
        _getAMBStorage().n3ToEvmMessages[messageData.nonce] = AMBTypes.StoredMessage({
            encodedMetadata: messageData.encodedMetadata,
            message: messageData.message,
            executed: false
        });

        emit MessageDeposit(messageData.nonce, messageData.message);
    }

    function executeMessage(uint256 nonce)
        external
        payable
        nonReentrant
        whenExecutingNotPaused
        returns (AMBTypes.Result memory)
    {
        AMBTypes.StoredMessage storage storedMessage = _getAMBStorage().n3ToEvmMessages[nonce];
        bytes memory rawMessage = storedMessage.message;
        if (rawMessage.length == 0) revert MessageNotFound(nonce);
        if (storedMessage.executed) revert MessageAlreadyExecuted(nonce);
        IExecutionManager messageExecutionManager = _getAMBStorage().messageExecutionManager;

        if (address(messageExecutionManager) == address(0)) revert ExecutionManagerNotSet();

        bytes memory encodedMetadata = storedMessage.encodedMetadata;
        AMBTypes.MessageType msgType = MessageBridgeLib._readMessageType(encodedMetadata); // Ensure the message type is valid

        AMBTypes.MetadataExecutable memory metadata;
        if (msgType != AMBTypes.MessageType.EXECUTABLE) revert MessageBridgeLib.UnsupportedMessageType(msgType);
        else metadata = abi.decode(encodedMetadata, (AMBTypes.MetadataExecutable));

        // Check if the message execution window has expired
        AMBTypes.MessageConfig memory config = _getMessageBridgeConfig();
        uint256 expiry = metadata.timestamp + config.executionWindowSeconds;
        if (block.timestamp > expiry) revert ExecutionWindowExpired(expiry, block.timestamp);

        // Mark as executed
        storedMessage.executed = true;

        // Execute the message using the execution manager
        AMBTypes.Result memory result = messageExecutionManager.executeMessage{value: msg.value}(nonce, rawMessage);

        if (metadata.storeResult) _getAMBStorage().n3ToEvmExecutionResults[nonce] = result;

        emit MessageExecuted(nonce, result);

        return result;
    }

    function setMessageBridgeFee(uint256 _fee) external override onlyGovernor {
        _setMessageBridgeFee(_fee);
        emit MessageWithdrawalFeeChange(_fee);
    }

    function setMaxMessageSize(uint256 _maxSize) external override onlyGovernor {
        _setMaxMessageSize(_maxSize);
        emit MaxMessageSizeChange(_maxSize);
    }

    function setMaxNrMessages(uint256 _maxDeposits) external override onlyGovernor {
        _setMaxNrMessages(_maxDeposits);
        emit MaxNrMessagesChange(_maxDeposits);
    }

    function setMessageExecutor(address _executor) external override onlyGovernor {
        _getAMBStorage().messageExecutionManager = IExecutionManager(_executor);
        emit MessageExecutorSet(_executor);
    }

    function setExecutionWindowSeconds(uint256 windowSeconds) external override onlyGovernor {
        _setExecutionWindowSeconds(windowSeconds);
        emit MessageExecutionWindowChange(windowSeconds);
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyAdmin {}

    // Add public getter functions for testing
    function n3ToEvmMessages(uint256 nonce) external view returns (AMBTypes.StoredMessage memory storedMessage) {
        storedMessage = _getAMBStorage().n3ToEvmMessages[nonce];
    }

    function getMessageBridgeState() external view returns (AMBTypes.MessageBridgeState memory) {
        return _getAMBStorage().messageBridgeState;
    }

    // Modifiers

    modifier onlyAdmin() {
        if (msg.sender != GOV_ADMIN) revert UnauthorizedUpgrade();
        _;
    }

    modifier onlyRelayer() {
        if (msg.sender != _getAMBStorage().management.getRelayer()) revert NotRelayer();
        _;
    }

    modifier onlyGovernor() {
        if (msg.sender != _getAMBStorage().management.getGovernor()) revert NotGovernor();
        _;
    }

    modifier onlyGovernorOrSecurityGuard() {
        AMBStorage storage store = _getAMBStorage();
        if (msg.sender != store.management.getGovernor() && msg.sender != store.management.getSecurityGuard()) {
            revert NoAuthorization();
        }
        _;
    }

    modifier onlyIfMessageBridgeSet() {
        if (!_messageBridgeIsSet()) revert MessageBridgeNotSet();
        _;
    }

    modifier whenMessageBridgeNotPaused() {
        if (_getAMBStorage().messageBridgeState.paused) revert MessageBridgePaused();
        _;
    }

    modifier whenMessageBridgePaused() {
        if (!_getAMBStorage().messageBridgeState.paused) revert MessageBridgeNotPaused();
        _;
    }

    modifier whenSendingNotPaused() {
        if (_getAMBStorage().sendingPaused) revert SendingPaused();
        _;
    }

    modifier whenSendingPaused() {
        if (!_getAMBStorage().sendingPaused) revert SendingNotPaused();
        _;
    }

    modifier whenExecutingNotPaused() {
        if (_getAMBStorage().executingPaused) revert ExecutingPaused();
        _;
    }

    modifier whenExecutingPaused() {
        if (!_getAMBStorage().executingPaused) revert ExecutingNotPaused();
        _;
    }

    // Internal functions to be discarded

    function _messageBridgeIsSet() internal view returns (bool) {
        return _getAMBStorage().messageBridgeState.config.maxMessageSize != 0;
    }

    function _setMessageBridge(
        uint256 _fee,
        uint256 _maxMessageSize,
        uint256 _maxNrMessages,
        uint256 _executionWindowSeconds
    )
        internal
    {
        if (_fee == 0) revert InvalidFee();
        if (_maxMessageSize == 0) revert InvalidValue();
        if (_maxNrMessages == 0) revert InvalidValue();

        _getAMBStorage().messageBridgeState = AMBTypes.MessageBridgeState({
            paused: true,
            n3ToEvmState: StorageTypes.State({nonce: 0, root: 0x0}),
            evmToN3State: StorageTypes.State({nonce: 0, root: 0x0}),
            config: AMBTypes.MessageConfig({
                fee: _fee,
                maxMessageSize: _maxMessageSize,
                maxNrMessages: _maxNrMessages,
                executionWindowSeconds: _executionWindowSeconds
            })
        });
    }

    function _pauseMessageBridge() internal {
        _getAMBStorage().messageBridgeState.paused = true;
    }

    function _unpauseMessageBridge() internal {
        _getAMBStorage().messageBridgeState.paused = false;
    }

    function _getMessageBridgeConfig() internal view returns (AMBTypes.MessageConfig memory config) {
        return _getAMBStorage().messageBridgeState.config;
    }

    function _getMessageBridgeN3ToEvmState() internal view returns (StorageTypes.State memory state) {
        return _getAMBStorage().messageBridgeState.n3ToEvmState;
    }

    function _setMessageBridgeN3ToEvmState(StorageTypes.State memory state) internal {
        _getAMBStorage().messageBridgeState.n3ToEvmState = state;
    }

    function _getMessageBridgeEvmToN3State() internal view returns (StorageTypes.State memory state) {
        return _getAMBStorage().messageBridgeState.evmToN3State;
    }

    function _setMessageBridgeEvmToN3State(StorageTypes.State memory state) internal {
        _getAMBStorage().messageBridgeState.evmToN3State = state;
    }

    function _setMessageBridgeFee(uint256 _fee) internal {
        if (_fee == 0) revert InvalidFee();
        _getAMBStorage().messageBridgeState.config.fee = _fee;
    }

    function _setMaxMessageSize(uint256 _maxMessageSize) internal {
        if (_maxMessageSize == 0) revert InvalidValue();
        _getAMBStorage().messageBridgeState.config.maxMessageSize = _maxMessageSize;
    }

    function _setMaxNrMessages(uint256 _maxNrMessages) internal {
        if (_maxNrMessages == 0) revert InvalidValue();
        _getAMBStorage().messageBridgeState.config.maxNrMessages = _maxNrMessages;
    }

    function _setExecutionWindowSeconds(uint256 _executionWindowSeconds) internal {
        if (_executionWindowSeconds == 0) revert InvalidValue();
        _getAMBStorage().messageBridgeState.config.executionWindowSeconds = _executionWindowSeconds;
    }

    /**
     * @dev Checks the provided value against the required fee. If the provided value exceeds the required fee, the
     * excess amount is refunded if the sender is an EOA. Otherwise, if the sender is a contract, it is reverted.
     * @param _from the sender.
     * @param _msgValue the value sent with the transaction.
     * @param _fee the required fee.
     */
    function _processBridgeFee(address _from, uint256 _msgValue, uint256 _fee) private {
        // Revert if the provided value is lower than the required fee.
        if (_msgValue < _fee) revert InsufficientFee(_fee, _msgValue);
        // Refund the sender (only EOAs) if the provided value is higher than the required fee.
        if (_msgValue > _fee) {
            // Revert if the sender is a contract.
            if (BridgeLib._isContract(_from)) revert ExactFeeRequired(_fee, _msgValue);
            (bool success,) = payable(_from).call{value: _msgValue - _fee}("");
            if (!success) revert TransferFailed();
        }
        _getAMBStorage().unclaimedRewards += _fee;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IBridgeManagement} from "../interfaces/IBridgeManagement.sol";
import {AMBStorage} from "../messageBridge/AMBStorage.sol";
import {AMBTypes} from "../library/AMBTypes.sol";
import {MessageBridgeLib} from "../library/MessageBridgeLib.sol";
import {StorageTypes} from "../library/StorageTypes.sol";
import {MessageBridge} from "../messageBridge/MessageBridge.sol";

contract TestMessageBridge is MessageBridge {
    /// @custom:oz-upgrades-unsafe-allow constructor
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
        initializer
    {
        __ReentrancyGuard_init();
        getStorage().management = IBridgeManagement(_management);
        _setMessageBridge(_fee, _maxMessageSize, _maxNrMessages, _executionWindowSeconds);
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

        getStorage().messageBridgeState = MessageBridgeState({
            paused: true,
            sendingPaused: false,
            executingPaused: false,
            evmState: StorageTypes.State({nonce: 0, root: 0x0}),
            n3State: StorageTypes.State({nonce: 0, root: 0x0}),
            config: MessageConfig({
                fee: _fee,
                maxMessageSize: _maxMessageSize,
                maxNrMessages: _maxNrMessages,
                executionWindowSeconds: _executionWindowSeconds
            })
        });
    }

    /// @notice Stores a message in the AMB storage.
    /// @param messageData The message data to be stored, including nonce, encoded metadata, and the raw message.
    /// @dev This function is used to simulate the storage of a message in the AMB storage.
    function storeSingleMessage(AMBTypes.MessageData memory messageData) external {
        AMBStorage.AMB storage ambStorage = getStorage();
        ambStorage.evmMessages[messageData.nonce] =
            AMBStorage.StoredMessage({encodedMetadata: messageData.encodedMetadata, rawMessage: messageData.message});

        AMBTypes.MessageType msgType = MessageBridgeLib._readMessageType(messageData.encodedMetadata);
        if (msgType == AMBTypes.MessageType.EXECUTABLE) {
            uint256 window = ambStorage.messageBridgeState.config.executionWindowSeconds;
            // Use the block timestamp to set the expiration timestamp for the executable message
            // in case the relayer is down and does not relay the message in time.
            ambStorage.evmExecutableStates[messageData.nonce] =
                AMBStorage.ExecutableState({executed: false, expirationTimestamp: block.timestamp + window});
        }

        emit Store(messageData.nonce, messageData.message);
    }
}

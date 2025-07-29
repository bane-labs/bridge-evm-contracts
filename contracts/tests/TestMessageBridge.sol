// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IBridgeManagement} from "../interfaces/IBridgeManagement.sol";
import {AMBStorage} from "../library/AMBStorage.sol";
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
        AMBStorage.get().management = IBridgeManagement(_management);
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

        AMBStorage.get().messageBridgeState = AMBStorage.MessageBridgeState({
            paused: true,
            sendingPaused: false,
            executingPaused: false,
            n3ToEvmState: StorageTypes.State({nonce: 0, root: 0x0}),
            evmToN3State: StorageTypes.State({nonce: 0, root: 0x0}),
            config: AMBStorage.MessageConfig({
                fee: _fee,
                maxMessageSize: _maxMessageSize,
                maxNrMessages: _maxNrMessages,
                executionWindowSeconds: _executionWindowSeconds
            })
        });
    }
}

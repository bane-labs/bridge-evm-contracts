// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IBridgeManagement} from "../interfaces/IBridgeManagement.sol";
import {AMBStorage} from "../library/AMBStorage.sol";
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
        override
        initializer
    {
        __ReentrancyGuard_init();
        AMBStorage.get().management = IBridgeManagement(_management);
        _setMessageBridge(_fee, _maxMessageSize, _maxNrMessages, _executionWindowSeconds);
    }
}

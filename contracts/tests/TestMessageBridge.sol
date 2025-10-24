// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

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
        public
        override
    {
        __initialize(_management, _fee, _maxMessageSize, _maxNrMessages, _executionWindowSeconds);
    }
}

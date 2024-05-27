// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../bridge/BridgeImpl.sol";

// test
contract TestBridge is BridgeImpl {
    constructor(address m) BridgeImpl(m) {
    }


    function getTokenConfig (
        address neoXToken
    ) public view returns (StorageTypes.TokenConfig memory config) {
        config = _getTokenConfig(neoXToken);
        return config;
    }
}
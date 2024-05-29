// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../bridge/BridgeImpl.sol";

contract TestBridge is BridgeImpl {
    constructor(address m) BridgeImpl(m) {}

    function getTokenConfig(
        address neoXToken
    ) public view returns (StorageTypes.TokenConfig memory config) {
        config = _getTokenConfig(neoXToken);
        return config;
    }

    function getTokenbridge(
        address neoXToken
    ) public view returns (StorageTypes.TokenBridge memory tokenBridgeBefore) {
        return tokenBridges[neoXToken];
    }

    function getNeoN3Token(address _neoXToken) public view returns (address) {
        return tokenBridges[_neoXToken].config.neoN3Token;
    }

    function getTokenDepositState(
        address neoXToken
    ) public view returns (StorageTypes.State memory depositState) {
        return _getTokenDepositState(neoXToken);
    }

    function computeTokenRoot(
        bytes32 _previousRoot,
        address _neoN3Token,
        address _neoXToken,
        BridgeLib.DepositData[] calldata _deposits
    ) public returns (bytes32) {
        return
            TokenBridgeLib._computeNewTopRoot(
                _previousRoot,
                _neoN3Token,
                _neoXToken,
                _deposits
            );
    }
}

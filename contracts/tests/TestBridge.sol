// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../bridge/BridgeImpl.sol";

contract TestBridge is BridgeImpl {
    constructor(address m) BridgeImpl(m) {}

    function isRegisteredToken(address neoXToken) public view returns (bool) {
        return _isRegisteredToken(neoXToken);
    }

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
        return _getNeoN3Token(_neoXToken);
    }

    function getTokenDepositState(
        address neoXToken
    ) public view returns (StorageTypes.State memory depositState) {
        return _getTokenDepositState(neoXToken);
    }

    function getTokenWithdrawalState( address _neoXToken) public view returns (StorageTypes.State memory withdrawalState) {
        return _getTokenWithdrawalState(_neoXToken);
    }

    function computeTokenRoot(
        bytes32 _previousRoot,
        address _neoN3Token,
        address _neoXToken,
        BridgeLib.DepositData[] calldata _deposits
    ) public pure returns (bytes32) {
        return
            TokenBridgeLib._computeNewTopRoot(
                _previousRoot,
                _neoN3Token,
                _neoXToken,
                _deposits
            );
    }
}

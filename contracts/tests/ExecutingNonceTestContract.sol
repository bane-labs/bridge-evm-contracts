// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ExecutionManager} from "../messageBridge/ExecutionManager.sol";

contract ExecutingNonceTestContract {
    uint256 public capturedNonce;
    address public executionManager;

    event NonceCapture(uint256 nonce, address caller);

    constructor(address _executionManager) {
        executionManager = _executionManager;
    }

    function captureExecutingNonce() external returns (uint256) {
        uint256 nonce = ExecutionManager(executionManager).executingNonce();
        capturedNonce = nonce;
        emit NonceCapture(nonce, msg.sender);
        return nonce;
    }

    function getCapturedNonce() external view returns (uint256) {
        return capturedNonce;
    }
}

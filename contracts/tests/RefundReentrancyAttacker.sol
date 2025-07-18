// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBTypes} from "../library/AMBTypes.sol";
import {IMessageBridge} from "../messageBridge/interfaces/IMessageBridge.sol";

/**
 * @dev Contract to test refund reentrancy protection in ExecutionManager
 * This contract will attempt to exploit the refund mechanism to reenter the bridge or steal funds
 */
contract RefundReentrancyAttacker {
    IMessageBridge public bridge;
    uint256 public messageNonce;

    // Attack state tracking
    uint256 public attackCount = 0;
    bool public refundReceived = false;
    bool public reentrancyAttemptSuccess = false;
    string public lastError = "";

    // Records of call data
    uint256 public receivedValue;

    constructor(address _bridge) {
        bridge = IMessageBridge(_bridge);
    }

    // Function to be called by the bridge
    function attack() external payable returns (bool) {
        // Record the received value and increment attack count
        receivedValue = msg.value;
        attackCount++;

        return true;
    }

    // This function is called when receiving a refund
    receive() external payable {
        refundReceived = true;

        // Attempt to reenter the bridge during refund
        if (attackCount == 1) {
            try bridge.executeMessage(messageNonce) returns (AMBTypes.Result memory) {
                reentrancyAttemptSuccess = true;
            } catch Error(string memory error) {
                lastError = error;
            } catch {
                lastError = "Unknown error during reentrancy attempt";
            }
        }
    }

    // Setup the attack
    function setupAttack(uint256 _nonce) external {
        messageNonce = _nonce;
        attackCount = 0;
        refundReceived = false;
        reentrancyAttemptSuccess = false;
        lastError = "";
        receivedValue = 0;
    }
}

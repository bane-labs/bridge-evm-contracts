// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBTypes} from "../library/AMBTypes.sol";
import {IMessageBridge} from "../messageBridge/interfaces/IMessageBridge.sol";

/**
 * @dev Contract to test reentrancy protection in BridgeImpl's executeMessage function
 * This contract will attempt to call executeMessage again during an ongoing execution
 */
contract ReentrancyAttacker {
    IMessageBridge public bridge;
    uint256 public messageNonce;
    bool public attackMode = false;
    bool public firstCallSucceeded = false;
    bool public secondCallSucceeded = false;
    string public lastError = "";

    constructor(address _bridge) {
        bridge = IMessageBridge(_bridge);
    }

    // Function that will be called by the bridge
    function attack() external payable returns (bool) {
        // Record that first call succeeded
        firstCallSucceeded = true;

        // Only attempt reentrancy if in attack mode
        if (attackMode) {
            try bridge.executeMessage(messageNonce) returns (AMBTypes.Result memory) {
                secondCallSucceeded = true;
                return true;
            } catch Error(string memory error) {
                lastError = error;
                return false;
            } catch {
                lastError = "Unknown error during reentrancy attempt";
                return false;
            }
        }

        return true;
    }

    // Toggle attack mode on/off
    function setAttackMode(bool _attackMode, uint256 _nonce) external {
        attackMode = _attackMode;
        messageNonce = _nonce;
        // Reset state for new tests
        firstCallSucceeded = false;
        secondCallSucceeded = false;
        lastError = "";
    }

    // Allow the contract to receive ETH
    receive() external payable {}
}

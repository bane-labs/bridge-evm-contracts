// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBTypes} from "../library/AMBTypes.sol";
import {IExecutionManager} from "./interfaces/IExecutionManager.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract ExecutionManager is IExecutionManager, AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    uint256 public executingNonce;

    //0x15fcd675
    error ExecutionFailed(bytes returnData);
    //0x626ade30
    error ValueMismatch(uint256 providedValue, uint256 expectedValue);
    //0xf0c49d44
    error RefundFailed();
    //0x7f12c702
    error SelfCallNotAllowed();

    constructor(address bridge) {
        _grantRole(BRIDGE_ROLE, bridge);
    }

    // Only the bridge contract can execute messages
    function executeMessage(
        uint256 nonce,
        bytes calldata rawMessage,
        address payable refundAddress
    )
        external
        payable
        override
        onlyRole(BRIDGE_ROLE)
        returns (AMBTypes.Result memory result)
    {
        // If rawMessage contains data that doesn't match the structure of the Call struct
        // the transaction will fail with a decoding error
        AMBTypes.Call memory call = abi.decode(rawMessage, (AMBTypes.Call));

        if (call.target == address(this)) revert SelfCallNotAllowed();

        executingNonce = nonce;

        (bool success, bytes memory returnData) = _executeCall(call.target, call.value, call.callData);
        if (!success) {
            // If the call failed and it's not allowed to fail, revert the entire transaction
            if (!call.allowFailure) revert ExecutionFailed(returnData);
            // If the call is allowed to fail, refund the value sent for the call (if any)
            if (call.value > 0) {
                (bool refundSuccess,) = refundAddress.call{value: call.value}("");
                // If the refund fails, revert the entire transaction to avoid losing funds
                if (!refundSuccess) revert RefundFailed();
            }
        }

        executingNonce = 0;

        result = AMBTypes.Result({success: success, returnData: returnData});
    }

    function _executeCall(
        address target,
        uint256 value,
        bytes memory callData
    )
        private
        returns (bool success, bytes memory returnData)
    {
        if (msg.value != value) revert ValueMismatch(msg.value, value);

        (success, returnData) = target.call{value: value}(callData);
    }
}

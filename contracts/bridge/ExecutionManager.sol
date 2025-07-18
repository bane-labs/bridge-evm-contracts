// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IExecutionManager} from "../interfaces/IExecutionManager.sol";
import {StorageTypes} from "../library/StorageTypes.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract ExecutionManager is IExecutionManager, AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    //0x15fcd675
    error ExecutionFailed(bytes returnData);
    //0x626ade30
    error ValueMismatch(uint256 providedValue, uint256 expectedValue);

    event RefundFailed(bytes reason);

    constructor(address bridge) {
        _grantRole(BRIDGE_ROLE, bridge);
    }

    // Only the bridge contract can execute messages
    function executeMessage(
        uint256, // nonce
        bytes calldata rawMessage,
        address payable refundTarget
    )
        external
        payable
        override
        onlyRole(BRIDGE_ROLE)
        returns (bool requiresResponse, StorageTypes.Result memory)
    {
        // If rawMessage contains data that doesn't match the structure of the Call struct
        // the transaction will fail with a decoding error
        StorageTypes.Call memory call = abi.decode(rawMessage, (StorageTypes.Call));

        (bool success, bytes memory returnData) = _executeCall(call.target, call.value, call.callData, refundTarget);
        if (!success && !call.allowFailure) revert ExecutionFailed(returnData);

        return (call.requiresResponse, StorageTypes.Result({success: success, returnData: returnData}));
    }

    function _executeCall(
        address target,
        uint256 value,
        bytes memory callData,
        address payable refundTarget
    )
        private
        returns (bool success, bytes memory returnData)
    {
        if (msg.value < value) revert ValueMismatch(msg.value, value);

        (success, returnData) = target.call{value: value}(callData);

        // Refund any excess value sent with the call
        if (msg.value > value) {
            (bool refundSuccess, bytes memory refundReturnData) = refundTarget.call{value: msg.value - value}("");
            if (!refundSuccess) {
                // If the refund fails, we revert the entire transaction
                emit RefundFailed(refundReturnData);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBTypes} from "../library/AMBTypes.sol";
import {IExecutionManager} from "./interfaces/IExecutionManager.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract ExecutionManager is IExecutionManager, AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    //0x15fcd675
    error ExecutionFailed(bytes returnData);
    //0x626ade30
    error ValueMismatch(uint256 providedValue, uint256 expectedValue);

    constructor(address bridge) {
        _grantRole(BRIDGE_ROLE, bridge);
    }

    // Only the bridge contract can execute messages
    function executeMessage(
        uint256, // nonce
        bytes calldata rawMessage
    )
        external
        payable
        override
        onlyRole(BRIDGE_ROLE)
        returns (bool requiresResponse, AMBTypes.Result memory)
    {
        // If rawMessage contains data that doesn't match the structure of the Call struct
        // the transaction will fail with a decoding error
        AMBTypes.Call memory call = abi.decode(rawMessage, (AMBTypes.Call));

        (bool success, bytes memory returnData) = _executeCall(call.target, call.value, call.callData);
        if (!success && !call.allowFailure) revert ExecutionFailed(returnData);

        return (call.requiresResponse, AMBTypes.Result({success: success, returnData: returnData}));
    }

    function _executeCall(
        address target,
        uint256 value,
        bytes memory callData
    )
        private
        returns (bool success, bytes memory returnData)
    {
        if (msg.value < value) revert ValueMismatch(msg.value, value);

        (success, returnData) = target.call{value: msg.value}(callData);
    }
}

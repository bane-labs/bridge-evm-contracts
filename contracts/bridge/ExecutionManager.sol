// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../interfaces/IExecutionManager.sol";
import "../library/StorageTypes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ExecutionManager is IExecutionManager, AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    error UnexpectedDelegation();
    error UnableToExecuteCall();
    //0x626ade30
    error ValueMismatch(uint256 providedValue, uint256 expectedValue);

    constructor(address admin, address bridge) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(BRIDGE_ROLE, bridge);
    }

    // Only the bridge contract can execute messages
    function executeMessage(
        bytes calldata rawMessage,
        address delegatedExecutor
    )
        external
        payable
        override
        onlyRole(BRIDGE_ROLE)
        returns (StorageTypes.Result memory)
    {
        // Decode the raw message into a StorageTypes.Call struct
        StorageTypes.Call memory call = abi.decode(rawMessage, (StorageTypes.Call));

        bool success;
        bytes memory returnData;

        // Check that this is the executing contract
        if (call.executingContract == address(this)) {
            if (delegatedExecutor != address(0)) {
                revert UnexpectedDelegation();
            } else {
                (success, returnData) = _executeCall(call.target, call.callData, call.value);

                if (!success && call.allowFailure) revert(string(returnData));
            }
        } else if (delegatedExecutor == address(0)) {
            revert UnableToExecuteCall();
        } else {
            (success, returnData) = IDelegatedExecutor(delegatedExecutor).executeCall{value: msg.value}(
                call.target, call.callData, call.value
            );
        }
        return StorageTypes.Result({success: success, requiresResponse: call.requiresResponse, returnData: returnData});
    }

    function _executeCall(
        address target,
        bytes memory callData,
        uint256 value
    )
        internal
        returns (bool success, bytes memory returnData)
    {
        if (msg.value < value) revert ValueMismatch(msg.value, value);

        (success, returnData) = target.call{value: value}(callData);
    }
}

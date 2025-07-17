// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../interfaces/IExecutionManager.sol";
import "../library/StorageTypes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ExecutionManager is IExecutionManager, AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    //0x15fcd675
    error ExecutionFailed(bytes returnData);
    //0xb96bcfbf
    error UnableToExecuteCall();
    //0x626ade30
    error ValueMismatch(uint256 providedValue, uint256 expectedValue);

    constructor(address bridge) {
        _grantRole(BRIDGE_ROLE, bridge);
    }

    // Only the bridge contract can execute messages
    function executeMessage(uint256 nonce, bytes calldata rawMessage)
        external
        payable
        override
        onlyRole(BRIDGE_ROLE)
        returns (StorageTypes.Result memory)
    {
        // If rawMessage contains data that doesn't match the structure of the Call struct
        // the transaction will fail with a decoding error
        StorageTypes.Call memory call = abi.decode(rawMessage, (StorageTypes.Call));

        bool success;
        bytes memory returnData;

        // Check that this is the executing contract
        if (call.delegatedExecutor == address(this) || call.delegatedExecutor == address(0)) {
            (success, returnData) = _executeCall(call.target, call.callData, call.value);
            if (!success && !call.allowFailure) revert ExecutionFailed(returnData);
        } else {
            // check that the delegated executor is a valid contract
            if (!isContract(call.delegatedExecutor)) revert UnableToExecuteCall();

            (success, returnData) = IDelegatedExecutor(call.delegatedExecutor).executeCall{value: msg.value}(
                nonce, call.target, call.callData, call.value
            );
        }
        return StorageTypes.Result({success: success, requiresResponse: call.requiresResponse, returnData: returnData});
    }

    function _executeCall(
        address target,
        bytes memory callData,
        uint256 value
    )
        private
        returns (bool success, bytes memory returnData)
    {
        if (msg.value < value) revert ValueMismatch(msg.value, value);

        (success, returnData) = target.call{value: msg.value}(callData);
    }

    function isContract(address _address) private view returns (bool) {
        uint256 codeSize;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            codeSize := extcodesize(_address)
        }
        return codeSize > 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../interfaces/IMessageExecutor.sol";
import "../library/StorageTypes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MessageExecutor is IMessageExecutor, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    // Store allowed targets and function selectors
    mapping(address => mapping(bytes4 => bool)) public allowedCalls;

    constructor(address admin, address bridge) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(BRIDGE_ROLE, bridge);
    }

    // Only the bridge contract can execute messages
    function executeMessage(address target, bytes calldata callData, uint256 value)
        external
        payable
        override
        onlyRole(BRIDGE_ROLE)
        returns (StorageTypes.Result memory)
    {
        // Check if call is allowed
        bytes4 selector = bytes4(callData[:4]);
        require(isCallAllowed(target, selector), "Call not allowed");

        StorageTypes.Result memory result;
        (result.success, result.returnData) = target.call{value: value}(callData);

        return result;
    }

    function isCallAllowed(address target, bytes4 selector) public view override returns (bool) {
        return allowedCalls[target][selector];
    }

    // Admin functions to manage allowed calls
    function setCallAllowed(address target, bytes4 selector, bool allowed) external onlyRole(ADMIN_ROLE) {
        allowedCalls[target][selector] = allowed;
    }

    function setBatchCallsAllowed(
        address[] calldata targets,
        bytes4[] calldata selectors,
        bool[] calldata allowedValues
    ) external onlyRole(ADMIN_ROLE) {
        require(targets.length == selectors.length && selectors.length == allowedValues.length, "Length mismatch");

        for (uint i = 0; i < targets.length; i++) {
            allowedCalls[targets[i]][selectors[i]] = allowedValues[i];
        }
    }
}

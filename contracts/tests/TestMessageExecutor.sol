// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../interfaces/IMessageExecutor.sol";
import "../library/StorageTypes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title TestMessageExecutor
 * @dev Test implementation of the MessageExecutor with a more permissive execution model for testing
 */
contract TestMessageExecutor is IMessageExecutor, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    // For testing, we'll use a flag to enable/disable the allowlist validation
    bool public useAllowlist = false;

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
        // Only check allowlist if enabled (for testing purposes)
        if (useAllowlist) {
            bytes4 selector = bytes4(callData.length >= 4 ? bytes4(callData[:4]) : bytes4(0));
            require(isCallAllowed(target, selector), "Call not allowed");
        }

        StorageTypes.Result memory result;
        // Forward the call and correctly preserve msg.sender as the bridge
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        result.success = success;
        result.returnData = returnData;

        return result;
    }

    function isCallAllowed(address target, bytes4 selector) public view override returns (bool) {
        // For testing, we're more permissive - if allowlist is disabled, all calls are allowed
        if (!useAllowlist) {
            return true;
        }
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

    // Testing helper function to enable/disable allowlist
    function setUseAllowlist(bool _useAllowlist) external onlyRole(ADMIN_ROLE) {
        useAllowlist = _useAllowlist;
    }
}

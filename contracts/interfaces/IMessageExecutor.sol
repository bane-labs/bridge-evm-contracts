// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../library/StorageTypes.sol";

interface IMessageExecutor {
    function executeMessage(address target, bytes calldata callData, uint256 value) external payable returns (StorageTypes.Result memory);
    function isCallAllowed(address target, bytes4 selector) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IDelegatedExecutor {
    function executeCall(
        address target,
        bytes calldata callData,
        uint256 value
    )
        external
        payable
        returns (bool success, bytes memory returnData);
}

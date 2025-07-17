// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IDelegatedExecutor {
    function executeCall(
        uint256 nonce,
        address target,
        bytes calldata callData,
        uint256 value
    )
        external
        payable
        returns (bool success, bytes memory returnData);
}

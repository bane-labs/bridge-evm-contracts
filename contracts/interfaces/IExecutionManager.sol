// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../library/StorageTypes.sol";
import "./IDelegatedExecutor.sol";

interface IExecutionManager {
    function executeMessage(
        bytes calldata rawMessage,
        address delegatedExecutor
    )
        external
        payable
        returns (StorageTypes.Result memory);
}

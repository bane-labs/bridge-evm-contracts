// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../library/StorageTypes.sol";
import "./IDelegatedExecutor.sol";

interface IExecutionManager {
    function executeMessage(uint256 nonce, bytes calldata rawMessage) external payable returns (StorageTypes.Result memory);
}

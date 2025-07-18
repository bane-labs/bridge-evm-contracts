// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {StorageTypes} from "../library/StorageTypes.sol";

interface IExecutionManager {
    function executeMessage(
        uint256 nonce,
        bytes calldata rawMessage,
        address payable refundTarget
    )
        external
        payable
        returns (bool requiresResponse, StorageTypes.Result memory);
}

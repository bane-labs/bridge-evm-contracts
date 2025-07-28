// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBTypes} from "../../library/AMBTypes.sol";

interface IExecutionManager {
    function executeMessage(
        uint256 nonce,
        bytes calldata rawMessage
    )
        external
        payable
        returns (AMBTypes.Result memory result);
}

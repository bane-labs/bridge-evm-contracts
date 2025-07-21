// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IBridgeManagement} from "../../interfaces/IBridgeManagement.sol";

interface ITestBridgeManagement is IBridgeManagement {
    function owner() external view returns (address);
}

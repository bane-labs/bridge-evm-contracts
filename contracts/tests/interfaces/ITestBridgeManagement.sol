// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../../interfaces/IBridgeManagement.sol";

interface ITestBridgeManagement is IBridgeManagement {
    function owner() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// This Contract is only used to test the bridge contract
contract TestPayableContract {
    receive() external payable {}
}

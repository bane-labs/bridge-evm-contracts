// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// This Contract is only used to test HashTreeBridgeContract
contract TestPayableContract {
    receive() external payable {}
    fallback() external payable {}
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// This Contract is only used to test the bridge contract
contract TestPayableContract {
    receive() external payable {}
}

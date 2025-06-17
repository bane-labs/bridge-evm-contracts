// filepath: /Users/otnielnicola/projects/bridge-evm-contracts/test/helpers/TestContract.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TestContract {
    uint256 public counter;

    event TestEvent(uint256 indexed counter, address indexed caller);

    constructor() {
        counter = 0;
    }

    function testFunction() public returns (uint256) {
        counter += 1;
        emit TestEvent(counter, msg.sender);
        return counter;
    }
}

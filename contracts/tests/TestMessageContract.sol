// filepath: /Users/otnielnicola/projects/bridge-evm-contracts/test/helpers/TestContract.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TestMessageContract {
    uint256 public counter;

    event TestEvent(uint256 indexed counter, address indexed caller);
    event PaymentReceived(uint256 indexed amount, address indexed sender);
    event FallbackCalled(address indexed sender, uint256 amount, bytes data);
    event DirectEthReceived(address indexed sender);

    // Custom error for when the sent value doesn't match the amount parameter
    error ValueMismatch(uint256 expected, uint256 received);
    // Custom error for when the calldata doesn't contain a valid address
    error InvalidCallData();
    // Custom error for when amount or value is zero
    error ZeroValueNotAllowed();

    constructor() {
        counter = 0;
    }

    function testFunction() public returns (uint256) {
        counter += 1;
        emit TestEvent(counter, msg.sender);
        return counter;
    }

    function receivePayment(uint256 amount) external payable returns (bool) {
        if (amount == 0 || msg.value == 0) revert ZeroValueNotAllowed();
        if (msg.value != amount) revert ValueMismatch(amount, msg.value);
        emit PaymentReceived(amount, msg.sender);
        return true;
    }

    // Replace receive function with fallback function since we need to access msg.data
    fallback() external payable {
        // Reject zero value transfers
        if (msg.value == 0) revert ZeroValueNotAllowed();

        // Ensure calldata contains a valid address (should be exactly 20 bytes)
        if (msg.data.length != 20) revert InvalidCallData();

        // Extract the address from calldata
        address recipient;
        assembly {
            recipient := shr(96, calldataload(0))
        }

        // Emit event with the amount, sender and full calldata
        emit FallbackCalled(msg.sender, msg.value, msg.data);
    }

    // Simple receive function for plain ETH transfers
    receive() external payable {
        // Reject zero value transfers
        if (msg.value == 0) revert ZeroValueNotAllowed();

        emit DirectEthReceived(msg.sender);
    }
}

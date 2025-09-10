// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBTypes} from "../library/AMBTypes.sol";

/**
 * @title FailingContract
 * @notice A contract that always fails when called, used for testing refund scenarios
 */
contract FailingContract {
    error AlwaysFails();

    function alwaysFail() external payable {
        revert AlwaysFails();
    }

    fallback() external payable {
        revert AlwaysFails();
    }

    receive() external payable {
        revert AlwaysFails();
    }
}

/**
 * @title RefundReceiver
 * @notice A contract that can receive refunds and track them
 */
contract RefundReceiver {
    uint256 public refundCount;
    uint256 public totalRefunded;

    event RefundReceived(uint256 amount, address sender);

    receive() external payable {
        refundCount++;
        totalRefunded += msg.value;
        emit RefundReceived(msg.value, msg.sender);
    }

    function getRefundInfo() external view returns (uint256 count, uint256 total) {
        return (refundCount, totalRefunded);
    }
}

/**
 * @title NonPayableContract
 * @notice A contract that does not accept ether, used to test refund failures
 */
contract NonPayableContract {
    // This contract cannot receive ether - no receive() or payable fallback
    function dummy() external pure returns (bool) {
        return true;
    }
}

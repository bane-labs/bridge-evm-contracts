// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBTypes} from "../../library/AMBTypes.sol";
import {BridgeLib} from "../../library/BridgeLib.sol";

interface IMessageBridge {
    event MessageBridgeRegister(AMBTypes.MessageConfig config);
    event MessageBridgePause();
    event MessageBridgeUnpause();
    event MessageDeposit(uint256 indexed nonce, bytes message);
    event MessageDepositRootUpdate(uint256 indexed nonce, bytes32 depositRoot);
    event MessageWithdrawalFeeChange(uint256 fee);
    event MaxMessageSizeChange(uint256 maxSize);
    event MaxNrMessagesChange(uint256 maxDeposits);
    event MessageExecutionWindowChange(uint256 windowSeconds);
    event MessageExecutorSet(address indexed executor);
    event MessageExecuted(uint256 indexed nonce, AMBTypes.Result result);

    function messageBridgeIsSet() external view returns (bool);
    function pauseMessageBridge() external;
    function unpauseMessageBridge() external;
    function storeMessage(
        bytes32 depositRoot,
        BridgeLib.Signature[] calldata signatures,
        AMBTypes.MessageData[] calldata messages
    )
        external;

    function executeMessage(uint256 nonce) external payable returns (AMBTypes.Result memory);
    function setMessageBridgeFee(uint256 fee) external;
    function setMaxMessageSize(uint256 maxSize) external;
    function setMaxNrMessages(uint256 maxDeposits) external;
    function setMessageExecutor(address _executor) external;
    function setExecutionWindowSeconds(uint256 windowSeconds) external;
}

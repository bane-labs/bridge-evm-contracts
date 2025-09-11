// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBTypes} from "../../library/AMBTypes.sol";
import {BridgeLib} from "../../library/BridgeLib.sol";
import {AMBStorage} from "../AMBStorage.sol";

interface IMessageBridge {
    event MessageBridgePause();
    event MessageBridgeUnpause();
    event SendingPause();
    event SendingUnpause();
    event ExecutingPause();
    event ExecutingUnpause();
    event MessageDeposit(uint256 indexed nonce, bytes message);
    event MessageDepositRootUpdate(uint256 indexed nonce, bytes32 depositRoot);
    event MessageWithdrawalFeeChange(uint256 fee);
    event MaxMessageSizeChange(uint256 maxSize);
    event MaxNrMessagesChange(uint256 maxDeposits);
    event MessageExecutionWindowChange(uint256 windowSeconds);
    event MessageExecutorSet(address indexed executor);
    event MessageExecuted(uint256 indexed nonce, AMBTypes.Result result);
    event MessageSent(
        uint256 indexed nonce,
        address indexed sender,
        bytes encodedMetadata,
        bytes message,
        bytes32 messageHash,
        bytes32 newRoot
    );

    function pauseMessageBridge() external;
    function unpauseMessageBridge() external;
    function isMessageBridgePaused() external view returns (bool);
    function pauseSending() external;
    function unpauseSending() external;
    function isSendingPaused() external view returns (bool);
    function pauseExecuting() external;
    function unpauseExecuting() external;
    function isExecutingPaused() external view returns (bool);
    function getExecutableState(uint256 nonce)
        external
        view
        returns (AMBStorage.ExecutableState memory executableState);
    function sendMessage(bytes calldata message) external payable returns (uint256 nonce);
    function sendExecutableMessage(
        bytes calldata _message,
        bool storeResult
    )
        external
        payable
        returns (uint256 nonce);
    function sendResultMessage(uint256 relatedMessageNonce) external payable returns (uint256 nonce);
    function getResult(uint256 relatedMessageNonce) external view returns (AMBTypes.Result memory result);
    function storeMessage(
        bytes32 depositRoot,
        BridgeLib.Signature[] calldata signatures,
        AMBTypes.MessageData[] calldata messages
    )
        external;

    function executeMessage(uint256 nonce) external payable returns (AMBTypes.Result memory);
    function setMessageBridgeFee(uint256 fee) external;
    function setMaxMessageSize(uint256 maxSize) external;
    function setMaxNrMessages(uint256 maxNrMessages) external;
    function setMessageExecutor(address executor) external;
    function setExecutionWindowSeconds(uint256 windowSeconds) external;
}

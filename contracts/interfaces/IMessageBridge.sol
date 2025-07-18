// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BridgeLib} from "../library/BridgeLib.sol";
import {StorageTypes} from "../library/StorageTypes.sol";

interface IMessageBridge {
    event MessageBridgeRegister(StorageTypes.MessageConfig config);
    event MessageBridgePause();
    event MessageBridgeUnpause();
    event MessageDeposit(uint256 indexed nonce, bytes message);
    event MessageDepositRootUpdate(uint256 indexed nonce, bytes32 depositRoot);
    event MessageWithdrawalFeeChange(uint256 fee);
    event MaxMessageSizeChange(uint256 maxSize);
    event MaxNrMessagesChange(uint256 maxDeposits);
    event MessageExecutorSet(address indexed executor);

    function setMessageBridge(uint256 fee, uint256 maxMessageSize, uint256 maxDeposits) external;
    function messageBridgeIsSet() external view returns (bool);
    function pauseMessageBridge() external;
    function unpauseMessageBridge() external;
    function storeMessage(
        bytes32 depositRoot,
        BridgeLib.Signature[] calldata signatures,
        StorageTypes.MessageData[] calldata messages
    )
        external;
    function executeMessage(uint256 nonce) external payable returns (StorageTypes.Result memory);
    function setMessageBridgeFee(uint256 fee) external;
    function setMaxMessageSize(uint256 maxSize) external;
    function setMaxNrMessages(uint256 maxDeposits) external;
    function setMessageExecutor(address _executor) external;
}

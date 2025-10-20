// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBTypes} from "../contracts/library/AMBTypes.sol";
import {BridgeLib} from "../contracts/library/BridgeLib.sol";
import {MessageBridgeLib} from "../contracts/library/MessageBridgeLib.sol";
import {StorageTypes} from "../contracts/library/StorageTypes.sol";
import {AMBStorage} from "../contracts/messageBridge/AMBStorage.sol";
import {ExecutionManager} from "../contracts/messageBridge/ExecutionManager.sol";
import {MessageBridge} from "../contracts/messageBridge/MessageBridge.sol";
import {IMessageBridge} from "../contracts/messageBridge/interfaces/IMessageBridge.sol";
import {ReentrancyAttacker} from "../contracts/tests/ReentrancyAttacker.sol";
import {ExecutingNonceTestContract} from "../contracts/tests/ExecutingNonceTestContract.sol";
import {FailingContract, RefundReceiver, NonPayableContract} from "../contracts/tests/RefundTestContracts.sol";
import {TestContract} from "../contracts/tests/TestContract.sol";
import {TestPayableContract} from "../contracts/tests/TestPayableContract.sol";
import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {MessageBridgeTestHelper} from "./MessageBridgeTestHelper.sol";

contract MessageBridgeTest is MessageBridgeTestHelper {
    function test_StorageSlot() public pure {
        bytes32 computedSlot = keccak256(abi.encode(uint256(keccak256("AMB.storage")) - 1)) & ~bytes32(uint256(0xff));
        bytes32 storageSlot = 0xd6595d2280e6cba67baf67ff997445e733b244161e59228efeb7032069381100;
        assertEq(storageSlot, computedSlot, "Storage slot should match expected value");
    }

    function test_AllGetters() public {
        // Test management()
        address management = address(messageBridgeProxy.management());
        assertEq(management, address(managementProxy), "Management should match the management proxy");

        // Test executionManager()
        address executionMgr = address(messageBridgeProxy.executionManager());
        assertEq(executionMgr, address(executionManager), "Execution manager should match");

        // Test messageBridgeState()
        AMBStorage.MessageBridgeState memory state = messageBridgeProxy.messageBridgeState();
        assertFalse(state.paused, "Bridge should not be paused initially");
        assertFalse(state.sendingPaused, "Sending should not be paused initially");
        assertFalse(state.executingPaused, "Executing should not be paused initially");

        // Test getUnclaimedFees() - should be 0 initially
        uint256 initialFees = messageBridgeProxy.unclaimedFees();
        assertEq(initialFees, 0, "Initial unclaimed fees should be 0");

        // Store a message to test the remaining getters
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({
            nonce: state.neoToEvmState.nonce + 1,
            message: testMessage2,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: block.timestamp,
                    sender: address(this),
                    storeResult: true
                })
            )
        });

        bytes32 previousRoot = state.neoToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, messages);
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);
        vm.prank(relayer);
        messageBridgeProxy.storeMessages(depositRoot, signatures, messages);

        // Test getEvmMessage()
        AMBStorage.StoredMessage memory storedMessage = messageBridgeProxy.getEvmMessage(messages[0].nonce);
        assertEq(storedMessage.rawMessage, testMessage2, "Stored message should match original");
        assertEq(storedMessage.encodedMetadata, messages[0].encodedMetadata, "Stored metadata should match");

        // Test getEvmExecutableState() before execution
        AMBStorage.ExecutableState memory stateBefore = messageBridgeProxy.getEvmExecutableState(1);
        assertFalse(stateBefore.executed, "Message should not be executed initially");
        assertGt(stateBefore.expirationTimestamp, block.timestamp, "Expiration should be in future");

        // Execute the message
        vm.prank(governor);
        messageBridgeProxy.executeMessage(messages[0].nonce);

        // Test getEvmExecutableState() after execution
        AMBStorage.ExecutableState memory stateAfter = messageBridgeProxy.getEvmExecutableState(messages[0].nonce);
        assertTrue(stateAfter.executed, "Message should be executed");

        // Test getEvmExecutionResult()
        bytes memory executionResult = messageBridgeProxy.getEvmExecutionResult(messages[0].nonce);
        assertGt(executionResult.length, 0, "Execution result should be stored");
    }

    function test_MessageBridgePauseUnpause() public {
        // Test pausing
        vm.prank(governor);
        messageBridgeProxy.pause();

        // Try to deposit a message while paused (should revert)
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: block.timestamp,
                    sender: address(this),
                    storeResult: false
                })
            )
        });

        AMBStorage.MessageBridgeState memory bridgeState = messageBridgeProxy.messageBridgeState();
        bytes32 previousRoot = bridgeState.neoToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, messages);
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        vm.prank(relayer);
        vm.expectRevert(); // Should revert since bridge is paused
        messageBridgeProxy.storeMessages(depositRoot, signatures, messages);

        // Unpause and try again
        vm.prank(governor);
        messageBridgeProxy.unpause();

        // Now it should work (not reverting)
        vm.prank(relayer);
        messageBridgeProxy.storeMessages(depositRoot, signatures, messages);
    }

    function test_pauseSending() public {
        assertEq(messageBridgeProxy.sendingPaused(), false, "Sending should not be paused initially");

        // Fail unpausing when already unpaused
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.SendingNotPaused.selector));
        messageBridgeProxy.unpauseSending(); // Should revert since not paused

        // Fail pausing with unauthorized user
        vm.prank(funder);
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.NoAuthorization.selector));
        messageBridgeProxy.pauseSending(); // Should revert since not authorized

        // Pause sending
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.SendingPause();
        vm.prank(securityGuard);
        messageBridgeProxy.pauseSending();

        assertEq(messageBridgeProxy.sendingPaused(), true, "Sending should be paused");

        // Fail pausing when already paused
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.SendingPaused.selector));
        messageBridgeProxy.pauseSending(); // Should revert since already paused

        // Fail unpausing with unauthorized user
        vm.prank(securityGuard);
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.NotGovernor.selector));
        messageBridgeProxy.unpauseSending(); // Should revert since not authorized

        // Unpause sending
        vm.prank(governor);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.SendingUnpause();
        messageBridgeProxy.unpauseSending();
        assertEq(messageBridgeProxy.sendingPaused(), false, "Sending should be unpaused");
    }

    function test_pauseSending_disallowsSending() public {
        assertEq(messageBridgeProxy.sendingPaused(), false, "Sending should not be paused initially");

        vm.prank(governor);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.SendingPause();
        messageBridgeProxy.pauseSending();

        assertEq(messageBridgeProxy.sendingPaused(), true, "Sending should be paused");

        // Try to store a message while sending is paused (should revert)
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: block.timestamp,
                    sender: address(this),
                    storeResult: false
                })
            )
        });

        vm.expectRevert(abi.encodeWithSelector(MessageBridge.SendingPaused.selector));
        messageBridgeProxy.sendExecutableMessage(testMessage1, false);

        vm.expectRevert(abi.encodeWithSelector(MessageBridge.SendingPaused.selector));
        messageBridgeProxy.sendMessage(testMessage1);
    }

    function test_pauseExecuting() public {
        assertEq(messageBridgeProxy.executingPaused(), false, "Executing should not be paused initially");

        // Fail unpausing when already unpaused
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.ExecutingNotPaused.selector));
        messageBridgeProxy.unpauseExecuting(); // Should revert since not paused

        // Fail pausing with unauthorized user
        vm.prank(funder);
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.NoAuthorization.selector));
        messageBridgeProxy.pauseExecuting(); // Should revert since not authorized

        // Pause sending
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.ExecutingPause();
        vm.prank(securityGuard);
        messageBridgeProxy.pauseExecuting();

        assertEq(messageBridgeProxy.executingPaused(), true, "Executing should be paused");

        // Fail pausing when already paused
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.ExecutingPaused.selector));
        messageBridgeProxy.pauseExecuting(); // Should revert since already paused

        // Fail unpausing with unauthorized user
        vm.prank(securityGuard);
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.NotGovernor.selector));
        messageBridgeProxy.unpauseExecuting(); // Should revert since not authorized

        // Unpause sending
        vm.prank(governor);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.ExecutingUnpause();
        messageBridgeProxy.unpauseExecuting();
        assertEq(messageBridgeProxy.executingPaused(), false, "Executing should be unpaused");
    }

    function test_pauseExecuting_disallowsExecuting() public {
        assertEq(messageBridgeProxy.executingPaused(), false, "Executing should not be paused initially");

        vm.prank(governor);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.ExecutingPause();
        messageBridgeProxy.pauseExecuting();

        assertEq(messageBridgeProxy.executingPaused(), true, "Executing should be paused");

        uint256 nonce = 1;
        storeDummyMessage(nonce);

        vm.expectRevert(abi.encodeWithSelector(MessageBridge.ExecutingPaused.selector));
        messageBridgeProxy.executeMessage(nonce);
    }

    function test_StoreAndExecuteMessageWithTestContract() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        assertEq(testContract.counter(), 0, "Counter should be initialized to 0");

        // Create Call struct with testFunction encoded
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);

        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        uint256 nonce = 1;

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message and get the nonce
        storeMessage(nonce, message, "");

        // Expect the TestEvent to be emitted with correct parameters
        vm.expectEmit(true, true, true, true, address(testContract));
        emit TestContract.TestEvent(1, address(executionManager));

        // Expect the Execution event to be emitted with correct parameters
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.Execution(nonce, AMBTypes.Result({success: true, returnData: abi.encode(1)}));

        // Execute the message
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage(nonce);

        // Verify execution was successful
        assertTrue(result.success, "Message execution should succeed");

        // Verify the counter was incremented
        assertEq(testContract.counter(), 1, "Counter should be incremented to 1");

        // Decode the result data to verify the return value
        uint256 returnedCounter = abi.decode(result.returnData, (uint256));
        assertEq(returnedCounter, 1, "Returned counter should be 1");
    }

    function test_StoreAndExecuteMessageWithTestContractPayment() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        // Verify the contract did not receive any ETH
        assertEq(address(testContract).balance, 0, "Test contract should not have received ETH");

        // Create Call struct with receivePayment encoded
        uint256 paymentAmount = 1 ether;
        bytes memory callData = abi.encodeWithSelector(TestContract.receivePayment.selector, paymentAmount);

        AMBTypes.Call memory call = AMBTypes.Call({
            target: address(testContract),
            callData: callData,
            allowFailure: false,
            value: paymentAmount
        });
        uint256 nonce = 1;
        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message and get the nonce
        storeMessage(nonce, message, "");

        // Expect the PaymentReceived event to be emitted with correct parameters
        vm.expectEmit(true, true, true, true, address(testContract));
        emit TestContract.PaymentReceived(paymentAmount, address(executionManager));

        // Expect the Execution event to be emitted with correct parameters
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.Execution(nonce, AMBTypes.Result({success: true, returnData: abi.encode(true)}));

        // Execute the message
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: paymentAmount}(nonce);

        // Verify execution was successful
        assertTrue(result.success, "Message execution should succeed");

        // Decode the result data to verify the return value
        bool returnedSuccess = abi.decode(result.returnData, (bool));
        assertTrue(returnedSuccess, "Should return true");

        // Verify the contract received the 1 ETH
        assertEq(address(testContract).balance, call.value, "Payable contract should have received 1 ETH");
    }

    function test_StoreAndExecuteMessageWithTestContractPaymentMismatch() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        assertEq(address(testContract).balance, 0, "Test contract should not have ETH");

        // Create Call struct with receivePayment encoded but with mismatched values
        uint256 declaredAmount = 1 ether;
        uint256 actualAmount = 0.5 ether; // Mismatched amount
        bytes memory callData = abi.encodeWithSelector(TestContract.receivePayment.selector, declaredAmount);

        AMBTypes.Call memory call = AMBTypes.Call({
            target: address(testContract),
            callData: callData,
            allowFailure: true, // Allow failure so we can check the error
            value: actualAmount
        });
        uint256 nonce = 1;

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message and get the nonce
        storeMessage(nonce, message, "");

        // Create the expected error data for the value mismatch
        bytes memory expectedErrorData =
            abi.encodeWithSelector(TestContract.ValueMismatch.selector, declaredAmount, actualAmount);

        // Expect the Execution event to be emitted with failure result
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.Execution(nonce, AMBTypes.Result({success: false, returnData: expectedErrorData}));

        // Execute the message - this should fail but not revert the transaction
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: actualAmount}(nonce);

        // Verify execution failed as expected
        assertFalse(result.success, "Message execution should fail due to value mismatch");

        bytes memory errorBytes = result.returnData;

        // Verify that the error is a ValueMismatch error
        bytes4 errorSelector;
        assembly {
            errorSelector := mload(add(errorBytes, 0x20))
        }
        bytes4 expectedSelector = TestContract.ValueMismatch.selector;
        assertEq(errorSelector, expectedSelector, "Error selector should match ValueMismatch");

        // Decode and verify the error parameters using assembly
        uint256 expected;
        uint256 received;
        assembly {
            // Load the parameters after the selector (4 bytes)
            // Each parameter is 32 bytes
            expected := mload(add(errorBytes, 0x24)) // 0x20 (length prefix) + 0x04 (selector)
            received := mload(add(errorBytes, 0x44)) // 0x20 + 0x04 + 0x20 (first parameter)
        }

        assertEq(expected, declaredAmount, "Expected amount in error should match declared amount");
        assertEq(received, actualAmount, "Received amount in error should match actual amount sent");

        // Verify the contract did not receive any ETH
        assertEq(address(testContract).balance, 0, "Test contract should not have received ETH");
    }

    function test_StoreAndExecuteMessageWithTestContractDirectEth() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        assertEq(address(testContract).balance, 0, "Test contract should not have ETH");

        // Create Call struct with empty callData to trigger receive() function
        bytes memory callData = "";

        AMBTypes.Call memory call =
            AMBTypes.Call({target: address(testContract), callData: callData, allowFailure: false, value: 1 ether});

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        AMBStorage.MessageBridgeState memory bridgeState = messageBridgeProxy.messageBridgeState();
        uint256 nonce = bridgeState.neoToEvmState.nonce + 1;

        // Store the message with the nonce
        storeMessage(nonce, message, "");

        // Expect the DirectEthReceived event to be emitted with correct sender
        vm.expectEmit(true, true, true, true, address(testContract));
        emit TestContract.DirectEthReceived(address(executionManager));

        // Expect the Execution event to be emitted with success result
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.Execution(nonce, AMBTypes.Result({success: true, returnData: ""}));

        // Execute the message
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: 1 ether}(nonce);

        // Verify execution was successful
        assertTrue(result.success, "Message execution should succeed");

        // Verify the contract received the 1 ETH
        assertEq(address(testContract).balance, call.value, "Payable contract should have received 1 ETH");
    }

    function test_StoreAndExecuteMessageWithTestContractFallback() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        assertEq(address(testContract).balance, 0, "Test contract should not have ETH");

        // Create a valid address payload to send in the calldata
        bytes memory addressBytes = abi.encodePacked(address(this));

        AMBTypes.Call memory call =
            AMBTypes.Call({target: address(testContract), callData: addressBytes, allowFailure: false, value: 1 ether});

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        AMBStorage.MessageBridgeState memory bridgeState = messageBridgeProxy.messageBridgeState();
        uint256 nonce = bridgeState.neoToEvmState.nonce + 1;

        // Store the message with the nonce
        storeMessage(nonce, message, "");

        // Expect the FallbackCalled event to be emitted with correct parameters
        vm.expectEmit(true, true, true, true, address(testContract));
        emit TestContract.FallbackCalled(address(executionManager), 1 ether, addressBytes);

        // Expect the Execution event to be emitted with success result
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.Execution(nonce, AMBTypes.Result({success: true, returnData: ""}));

        // Execute the message
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: 1 ether}(nonce);

        // Verify execution was successful
        assertTrue(result.success, "Message execution should succeed");

        // Verify the contract received the 1 ETH
        assertEq(address(testContract).balance, call.value, "Test contract should have received 1 ETH");
    }

    function test_StoreAndExecuteMessageWithZeroValuePayment() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        assertEq(address(testContract).balance, 0, "Test contract should not have ETH");

        // Test 1: Zero value with receivePayment function
        {
            uint256 declaredAmount = 1 ether;
            uint256 actualAmount = 0; // Zero value
            bytes memory callData = abi.encodeWithSelector(TestContract.receivePayment.selector, declaredAmount);

            AMBTypes.Call memory call = AMBTypes.Call({
                target: address(testContract),
                callData: callData,
                allowFailure: true, // Allow failure so we can check the error
                value: actualAmount
            });

            bytes memory message = abi.encode(call);
            uint256 nonce = 1;
            storeMessage(nonce, message, "");
            AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: actualAmount}(nonce);

            // Verify execution failed as expected
            assertFalse(result.success, "Message execution should fail due to zero value");

            // Verify the error is ZeroValueNotAllowed
            bytes memory errorData = result.returnData;
            bytes4 errorSelector;
            assembly {
                errorSelector := mload(add(errorData, 0x20))
            }
            bytes4 expectedSelector = TestContract.ZeroValueNotAllowed.selector;
            assertEq(errorSelector, expectedSelector, "Error selector should match ZeroValueNotAllowed");

            // Verify the contract did not receive any ETH
            assertEq(address(testContract).balance, 0, "Test contract should not have received ETH");
        }

        // Test 2: Zero value with fallback function
        {
            bytes memory addressBytes = abi.encodePacked(address(this));

            AMBTypes.Call memory call = AMBTypes.Call({
                target: address(testContract),
                callData: addressBytes,
                allowFailure: true,
                value: 0 // Zero value
            });

            bytes memory message = abi.encode(call);
            uint256 nonce = 2;
            storeMessage(nonce, message, "");
            AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: 0}(nonce);

            // Verify execution failed as expected
            assertFalse(result.success, "Message execution should fail due to zero value in fallback");

            // Verify the error is ZeroValueNotAllowed
            bytes memory errorData = result.returnData;
            bytes4 errorSelector;
            assembly {
                errorSelector := mload(add(errorData, 0x20))
            }
            bytes4 expectedSelector = TestContract.ZeroValueNotAllowed.selector;
            assertEq(errorSelector, expectedSelector, "Error selector should match ZeroValueNotAllowed");

            // Verify the contract did not receive any ETH
            assertEq(address(testContract).balance, 0, "Test contract should not have received ETH");
        }

        // Test 3: Zero value with receive function
        {
            bytes memory callData = "";

            AMBTypes.Call memory call = AMBTypes.Call({
                target: address(testContract),
                callData: callData,
                allowFailure: true,
                value: 0 // Zero value
            });

            bytes memory message = abi.encode(call);
            uint256 nonce = 3;
            storeMessage(nonce, message, "");
            AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: 0}(nonce);

            // Verify execution failed as expected
            assertFalse(result.success, "Message execution should fail due to zero value in receive");

            // Verify the error is ZeroValueNotAllowed
            bytes memory errorData = result.returnData;
            bytes4 errorSelector;
            assembly {
                errorSelector := mload(add(errorData, 0x20))
            }
            bytes4 expectedSelector = TestContract.ZeroValueNotAllowed.selector;
            assertEq(errorSelector, expectedSelector, "Error selector should match ZeroValueNotAllowed");
            // Verify the contract did not receive any ETH
            assertEq(address(testContract).balance, 0, "Test contract should not have received ETH");
        }
    }

    function test_StoreAndExecuteMessageWithTestContractInvalidCallData() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        assertEq(address(testContract).balance, 0, "Test contract should not have ETH");

        // Create an invalid payload that's not a valid function of this contract or an address (20 bytes)
        bytes memory invalidCallData = abi.encodeWithSignature("someFunction(uint256)", 123);

        AMBTypes.Call memory call = AMBTypes.Call({
            target: address(testContract),
            callData: invalidCallData,
            allowFailure: false, // This will cause CallFailed error
            value: 1 ether
        });

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message with a specific nonce
        uint256 nonce = 1;
        storeMessage(nonce, message, "");

        // Execution should revert with CallFailed(InvalidCallData())
        vm.expectRevert(
            abi.encodeWithSelector(
                ExecutionManager.ExecutionFailed.selector, abi.encodeWithSelector(TestContract.InvalidCallData.selector)
            )
        );

        // Execute the message
        messageBridgeProxy.executeMessage{value: 1 ether}(nonce);

        // Verify the contract did not receive any ETH
        assertEq(address(testContract).balance, 0, "Test contract should not have received ETH");
    }

    function test_StoreAndExecuteMessageWithEOACall() public {
        // Create a random address that doesn't have any contract deployed
        address nonExistentContract = address(0x1234567890123456789012345678901234567890);

        // Verify the address has no code - i.e. EOA, not a contract
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(nonExistentContract)
        }
        assertEq(codeSize, 0, "Target should not have any code");
        assertEq(address(nonExistentContract).balance, 0, "Test contract should not have ETH");

        // Create some random calldata
        bytes memory callData = abi.encodeWithSignature("someFunction(uint256)", 123);

        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: true, target: nonExistentContract, value: 0.1 ether, callData: callData});

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message with a specific nonce
        uint256 nonce = 1;
        storeMessage(nonce, message, "");

        // Execute the message - this should succeed when calling an EOA
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: 0.1 ether}(nonce);

        // Verify execution succeeded as expected when calling an EOA
        assertTrue(result.success, "Message execution should succeed when calling an EOA");

        // The return data should be empty since it's an EOA
        assertEq(result.returnData.length, 0, "Return data should be empty for an EOA");

        // Verify the contract received the 1 ETH
        assertEq(address(nonExistentContract).balance, call.value, "EOA should have received 0.1 ETH");

        // Even with allowFailure set to false, it should still succeed
        call.allowFailure = false;
        message = abi.encode(call);
        nonce = 2;
        storeMessage(nonce, message, "");

        // This should not revert
        result = messageBridgeProxy.executeMessage{value: 0.1 ether}(nonce);
        assertTrue(result.success, "Message execution should succeed when calling an EOA with allowFailure=false");
        // Verify the contract received the 1 ETH
        assertEq(address(nonExistentContract).balance, 2 * call.value, "EOA should have received another 0.1 ETH");
    }

    function test_StoreAndExecuteMessageStorageErrors() public {
        // Create a test message
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);

        // Get current state and nonce
        StorageTypes.State memory neoToEvmState = messageBridgeProxy.messageBridgeState().neoToEvmState;
        uint256 nonce = neoToEvmState.nonce + 1;

        // Store the message with the nonce
        storeMessage(nonce, message, "");

        // Try to store the same message with the same nonce again: should revert with MessageAlreadyExists
        vm.prank(relayer);
        storeMessage(nonce, message, abi.encodeWithSelector(MessageBridge.InvalidNonceSequence.selector));

        // Execute the stored message: should succeed
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage(nonce);

        assertTrue(result.success, "Message execution should succeed");

        // Try to execute a non-existent message: should revert with MessageNotFound
        uint256 nonExistentNonce = 999;
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.MessageNotFound.selector, nonExistentNonce));
        messageBridgeProxy.executeMessage(nonExistentNonce);
    }

    function test_StoreAndExecuteMessageNonExistentPayableFunction() public {
        // Deploy TestPayableContract (which doesn't have tryoutFunction)
        TestPayableContract payableContract = new TestPayableContract();
        assertEq(address(payableContract).balance, 0, "Payable contract should not have received ETH");

        // Create Call struct with testFunction selector (which TestPayableContract doesn't implement)
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);

        AMBTypes.Call memory call =
            AMBTypes.Call({target: address(payableContract), callData: callData, allowFailure: true, value: 0.1 ether});

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message with a specific nonce
        uint256 nonce = 1;
        storeMessage(nonce, message, "");

        // Execute the message - this should fail but not revert since allowFailure is true
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: 0.1 ether}(nonce);

        // Verify execution failed as expected - TestPayableContract doesn't implement this function
        assertFalse(result.success, "Message execution should fail when calling non-existent function");

        // Now try with allowFailure set to false - should revert
        call.allowFailure = false;
        message = abi.encode(call);
        nonce = 2;
        storeMessage(nonce, message, "");

        // This should revert with CallFailed error
        vm.expectRevert(abi.encodeWithSelector(ExecutionManager.ExecutionFailed.selector, ""));
        messageBridgeProxy.executeMessage{value: 0.1 ether}(nonce);

        // Check that payableContract did not receive funds when the function call failed
        assertEq(address(payableContract).balance, 0, "Payable contract should not have received ETH");
    }

    function test_StoreAndExecuteMessageReentrancy() public {
        // Deploy the reentrancy attacker contract
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(messageBridgeProxy));

        // Create a Call struct that targets the attacker's attack function
        bytes memory callData = abi.encodeWithSelector(ReentrancyAttacker.attack.selector);

        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(attacker), value: 0, callData: callData});
        uint256 nonce = 1;

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message
        storeMessage(nonce, message, "");

        // Set attack mode to try reentrancy with the same nonce
        attacker.setAttackMode(true, nonce);

        // Execute the message
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage(nonce);

        // Verify execution of first call was successful
        assertTrue(result.success, "First message execution should succeed");
        assertTrue(attacker.firstCallSucceeded(), "First call to attacker contract should succeed");

        // Verify reentrancy attempt failed
        assertFalse(attacker.secondCallSucceeded(), "Reentrancy attempt should fail");

        // Try to execute the message again directly (should fail)
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.MessageAlreadyExecuted.selector, nonce));
        messageBridgeProxy.executeMessage(nonce);
    }

    function test_StoreAndExecuteMessageMultipleTimes() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        // Create Call struct with testFunction encoded
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);

        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        uint256 nonce = 1;

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message
        storeMessage(nonce, message, "");

        // First execution should succeed
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage(nonce);
        assertTrue(result.success, "First execution should succeed");
        assertEq(testContract.counter(), 1, "Counter should be incremented to 1");

        // Second execution of the same message should revert with MessageAlreadyExecuted error
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.MessageAlreadyExecuted.selector, nonce));
        messageBridgeProxy.executeMessage(nonce);

        // Counter should still be 1 since second execution was reverted
        assertEq(testContract.counter(), 1, "Counter should still be 1 after failed second execution");

        // Now create and store a new message with a different nonce
        uint256 nonce2 = 2;
        storeMessage(nonce2, message, "");

        // Execute the new message - should succeed
        result = messageBridgeProxy.executeMessage(nonce2);
        assertTrue(result.success, "Execution of message with new nonce should succeed");
        assertEq(testContract.counter(), 2, "Counter should be incremented to 2");
    }

    // Test storeMessages function with random messages

    function test_N3ResultFunctions() public {
        // Step 1: Send an executable message from EVM to N3
        bytes memory executableMessage = abi.encodePacked("Test executable message to N3");

        // Test that no result exists for the upcoming executable message nonce
        uint256 upcomingNonce = messageBridgeProxy.neoToEvmState().nonce + 1;
        uint256 nonExistentResultNonce = messageBridgeProxy.getNeoExecutionResultNonce(upcomingNonce);
        assertEq(nonExistentResultNonce, 0, "No result should exist for upcoming executable message nonce");
        bytes memory nonExistentResult = messageBridgeProxy.getNeoExecutionResult(upcomingNonce);
        assertEq(nonExistentResult.length, 0, "No result data should exist for upcoming executable message nonce");

        // Send the executable message and get its nonce
        uint256 executableNonce = messageBridgeProxy.sendExecutableMessage{value: messageFee}(executableMessage, true);
        assertEq(executableNonce, upcomingNonce, "Executable message nonce should match upcoming nonce");

        // Verify the message was sent
        StorageTypes.State memory evmToNeoState = messageBridgeProxy.messageBridgeState().evmToNeoState;
        assertEq(evmToNeoState.nonce, executableNonce, "N3 state nonce should be updated");

        // Step 2: Simulate N3 sending back a result message
        bytes memory resultMessageData = abi.encode("Result from N3 for executable message");

        // Create a result message from N3 with the related nonce pointing to our executable message
        AMBTypes.MessageData[] memory resultMessages = new AMBTypes.MessageData[](1);
        resultMessages[0] = AMBTypes.MessageData({
            nonce: 1, // This will be the EVM nonce for the result message
            message: resultMessageData,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataResult({
                    msgType: AMBTypes.MessageType.RESULT,
                    timestamp: block.timestamp,
                    sender: address(0x1234), // Simulate N3 sender
                    relatedMessageNonce: executableNonce // Link to our executable message
                })
            )
        });

        // Store the result message from N3
        StorageTypes.State memory neoToEvmState = messageBridgeProxy.neoToEvmState();
        bytes32 previousRoot = neoToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, resultMessages);
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        vm.prank(relayer);
        messageBridgeProxy.storeMessages(depositRoot, signatures, resultMessages);

        // Step 3: Test getNeoExecutionResultNonce function
        uint256 resultNonce = messageBridgeProxy.getNeoExecutionResultNonce(executableNonce);
        assertEq(resultNonce, resultMessages[0].nonce, "Should return the correct result message nonce");

        // Step 4: Test getNeoExecutionResult function
        bytes memory retrievedResult = messageBridgeProxy.getNeoExecutionResult(executableNonce);
        assertEq(retrievedResult, resultMessageData, "Should return the correct result message data");

        // Step 5: Test with non-existent executable message
        uint256 nonExistentNonce = messageBridgeProxy.getNeoExecutionResultNonce(999);
        assertEq(nonExistentNonce, 0, "Should return 0 for non-existent executable message");

        bytes memory emptyResult = messageBridgeProxy.getNeoExecutionResult(999);
        assertEq(emptyResult.length, 0, "Should return empty bytes for non-existent executable message");
    }

    function test_StoreRandomMessages() public {
        // Prepare message data
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](2);
        messages[0] = AMBTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: block.timestamp,
                    sender: address(this),
                    storeResult: false
                })
            )
        });
        messages[1] = AMBTypes.MessageData({
            nonce: 2,
            message: testMessage2,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: block.timestamp,
                    sender: address(this),
                    storeResult: false
                })
            )
        });

        // Compute the deposit root
        StorageTypes.State memory neoToEvmState = messageBridgeProxy.neoToEvmState();
        bytes32 previousRoot = neoToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, messages);

        // Generate valid signatures from validators
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        // Perform deposit
        vm.prank(relayer);
        messageBridgeProxy.storeMessages(depositRoot, signatures, messages);

        // Verify messages were stored correctly
        // We need to decode the original messages to compare with what's stored
        AMBTypes.Call memory expectedCall1 = abi.decode(testMessage1, (AMBTypes.Call));
        AMBTypes.Call memory expectedCall2 = abi.decode(testMessage2, (AMBTypes.Call));

        // Get the stored Call struct components - public mappings return struct components, not the struct itself

        bytes memory message1 = messageBridgeProxy.getEvmMessage(messages[0].nonce).rawMessage;
        AMBTypes.Call memory actualCall = abi.decode(message1, (AMBTypes.Call));

        // Verify that stored Call struct components match the expected ones
        assertEq(actualCall.target, expectedCall1.target, "First message target should match");
        assertEq(actualCall.value, expectedCall1.value, "First message value should match");
        assertEq(actualCall.allowFailure, expectedCall1.allowFailure, "First message allowFailure should match");
        assertEq(actualCall.callData, expectedCall1.callData, "First message callData should match");

        bytes memory message2 = messageBridgeProxy.getEvmMessage(messages[1].nonce).rawMessage;
        actualCall = abi.decode(message2, (AMBTypes.Call));
        assertEq(actualCall.target, expectedCall2.target, "Second message target should match");
        assertEq(actualCall.value, expectedCall2.value, "Second message value should match");
        assertEq(actualCall.allowFailure, expectedCall2.allowFailure, "Second message allowFailure should match");
        assertEq(actualCall.callData, expectedCall2.callData, "Second message callData should match");
    }

    function test_StoreMessageInvalidRoot() public {
        // Prepare message data
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: block.timestamp,
                    sender: address(this),
                    storeResult: false
                })
            )
        });

        // Use an incorrect deposit root
        bytes32 invalidDepositRoot = bytes32(uint256(1));

        // Generate valid signatures for the INVALID root
        BridgeLib.Signature[] memory signatures = generateValidSignatures(invalidDepositRoot);

        // Expect revert due to invalid root
        vm.prank(relayer);
        vm.expectRevert(); // Should revert with InvalidRoot error
        messageBridgeProxy.storeMessages(invalidDepositRoot, signatures, messages);
    }

    function test_StoreMessageInvalidSignatures() public {
        // Prepare message data
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: block.timestamp,
                    sender: address(this),
                    storeResult: false
                })
            )
        });

        // Compute the correct deposit root
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(bytes32(0), messages);

        // Generate invalid signatures (from non-validators)
        BridgeLib.Signature[] memory invalidSignatures = new BridgeLib.Signature[](1);
        invalidSignatures[0] = BridgeLib.Signature({r: bytes32(0), s: bytes32(0), v: 0});

        // Expect revert due to invalid signatures
        vm.prank(relayer);
        vm.expectRevert(); // Should revert with InvalidValidatorSignatures error
        messageBridgeProxy.storeMessages(depositRoot, invalidSignatures, messages);
    }

    function test_StoreMessageInvalidNonceSequence() public {
        // Prepare message data with non-sequential nonces
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](2);
        messages[0] = AMBTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: block.timestamp,
                    sender: address(this),
                    storeResult: false
                })
            )
        });
        messages[1] = AMBTypes.MessageData({
            nonce: 3, // This should be 2 to be sequential
            message: testMessage2,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: block.timestamp,
                    sender: address(this),
                    storeResult: false
                })
            )
        });

        // Compute root (this doesn't validate nonce sequence)
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(bytes32(0), messages);

        // Generate valid signatures
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        // Expect revert due to invalid nonce sequence
        vm.prank(relayer);
        vm.expectRevert(); // Should revert with InvalidNonceSequence error
        messageBridgeProxy.storeMessages(depositRoot, signatures, messages);
    }

    function test_StoreMessagesMultipleTimes() public {
        // First deposit
        AMBTypes.MessageData[] memory messages1 = new AMBTypes.MessageData[](1);
        messages1[0] = AMBTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: block.timestamp,
                    sender: address(this),
                    storeResult: false
                })
            )
        });

        StorageTypes.State memory neoToEvmState = messageBridgeProxy.neoToEvmState();
        bytes32 previousRoot = neoToEvmState.root;
        bytes32 depositRoot1 = MessageBridgeLib._computeNewTopRoot(previousRoot, messages1);
        BridgeLib.Signature[] memory signatures1 = generateValidSignatures(depositRoot1);

        vm.prank(relayer);
        messageBridgeProxy.storeMessages(depositRoot1, signatures1, messages1);

        // Second deposit - nonce should continue from previous
        AMBTypes.MessageData[] memory messages2 = new AMBTypes.MessageData[](1);
        messages2[0] = AMBTypes.MessageData({
            nonce: 2,
            message: testMessage2,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: block.timestamp,
                    sender: address(this),
                    storeResult: false
                })
            )
        });

        // The new root should be computed based on the previous root
        bytes32 depositRoot2 = MessageBridgeLib._computeNewTopRoot(depositRoot1, messages2);
        BridgeLib.Signature[] memory signatures2 = generateValidSignatures(depositRoot2);

        vm.prank(relayer);
        messageBridgeProxy.storeMessages(depositRoot2, signatures2, messages2);

        // Decode the expected Call structs
        AMBTypes.Call memory expectedCall1 = abi.decode(testMessage1, (AMBTypes.Call));
        AMBTypes.Call memory expectedCall2 = abi.decode(testMessage2, (AMBTypes.Call));

        // Get the stored Call struct components - public mappings return struct components, not the struct itself
        bytes memory message1 = messageBridgeProxy.getEvmMessage(messages1[0].nonce).rawMessage;
        bytes memory message2 = messageBridgeProxy.getEvmMessage(messages2[0].nonce).rawMessage;
        AMBTypes.Call memory actualCall1 = abi.decode(message1, (AMBTypes.Call));
        AMBTypes.Call memory actualCall2 = abi.decode(message2, (AMBTypes.Call));

        // Verify that stored Call struct components match the expected ones
        assertEq(actualCall1.target, expectedCall1.target, "First message target should match");
        assertEq(actualCall1.value, expectedCall1.value, "First message value should match");
        assertEq(actualCall1.allowFailure, expectedCall1.allowFailure, "First message allowFailure should match");
        assertEq(actualCall1.callData, expectedCall1.callData, "First message callData should match");

        assertEq(actualCall2.target, expectedCall2.target, "Second message target should match");
        assertEq(actualCall2.value, expectedCall2.value, "Second message value should match");
        assertEq(actualCall2.allowFailure, expectedCall2.allowFailure, "Second message allowFailure should match");
        assertEq(actualCall2.callData, expectedCall2.callData, "Second message callData should match");
    }

    function test_StoreMessageMetadataVerification() public {
        // Create a test message
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);

        // Get current state and nonce
        StorageTypes.State memory initialState = messageBridgeProxy.neoToEvmState();
        uint256 nonce = initialState.nonce + 1;

        // Store the message with custom metadata
        uint256 timestamp = block.timestamp * 1000; // Pretend timestamp is in milliseconds

        // Store the message with the nonce
        storeMessage(nonce, message, "");

        // Retrieve the stored metadata and verify it
        AMBTypes.MetadataExecutable memory metadata = getExecutableMetadata(nonce);

        // Verify metadata fields
        assertEq(
            uint8(metadata.msgType),
            uint8(AMBTypes.MessageType.EXECUTABLE),
            "Metadata message type should be EXECUTABLE"
        );
        assertEq(metadata.timestamp, timestamp, "Metadata timestamp should match");
        assertEq(metadata.sender, address(this), "Metadata sender should match");
        assertEq(metadata.storeResult, false, "Metadata storeResult should be false");
    }

    function test_StoreMultipleMessagesWithMetadata() public {
        // Create two different test messages
        TestContract testContract = new TestContract();

        // First message
        bytes memory callData1 = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call1 =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData1});
        bytes memory message1 = abi.encode(call1);

        // Second message
        bytes memory callData2 = abi.encodeWithSelector(TestContract.receivePayment.selector, 1 ether);
        AMBTypes.Call memory call2 =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 1 ether, callData: callData2});
        bytes memory message2 = abi.encode(call2);

        // Get current state and nonce
        StorageTypes.State memory initialState = messageBridgeProxy.neoToEvmState();
        uint256 nonce1 = initialState.nonce + 1;
        uint256 nonce2 = nonce1 + 1;

        // Store first message
        uint256 timestamp1 = block.timestamp * 1000; // Pretend timestamp is in milliseconds
        storeMessage(nonce1, message1, "");

        // Store second message
        vm.warp(block.timestamp + 100); // Advance time by 100 seconds
        uint256 timestamp2 = block.timestamp * 1000; // Pretend timestamp is in milliseconds
        storeMessage(nonce2, message2, "");

        AMBStorage.StoredMessage memory storedMessage1 = messageBridgeProxy.getEvmMessage(nonce1);
        AMBTypes.MetadataExecutable memory metadata1 = getExecutableMetadata(nonce1);
        bytes memory storedRawMessage1 = storedMessage1.rawMessage;
        // verify first message metadata
        assertEq(metadata1.sender, address(this), "First message metadata sender should match");
        assertEq(metadata1.timestamp, timestamp1, "First message metadata timestamp should match");

        // Verify raw message is stored correctly
        assertEq(storedRawMessage1, message1, "First message content should match");

        AMBStorage.StoredMessage memory storedMessage2 = messageBridgeProxy.getEvmMessage(nonce2);
        AMBTypes.MetadataExecutable memory metadata2 = getExecutableMetadata(nonce2);
        bytes memory storedRawMessage2 = storedMessage2.rawMessage;
        // verify second message metadata
        // Note: timestamps are in milliseconds, as if they are coming from N3
        assertEq(metadata2.sender, address(this), "Second message metadata sender should match");
        assertEq(metadata2.timestamp, timestamp2, "Second message metadata timestamp should match");
        assertEq(metadata2.timestamp - metadata1.timestamp, 100_000, "Timestamp difference should be 100 seconds");

        // Verify raw message is stored correctly
        assertEq(storedRawMessage2, message2, "Second message content should match");
    }

    function test_StoreMessageWithCustomMetadata() public {
        // Create a test message
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);

        // Set up a specific sender and timestamp for metadata
        address customSender = address(0xABCD);

        // Ensure block.timestamp is large enough before subtracting
        vm.warp(block.timestamp + 3600 * 2); // Move 2 hours into the future first
        uint256 customTimestamp = block.timestamp - 3600; // 1 hour ago (safe now)

        // Create the message data with custom metadata
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({
            nonce: 1,
            message: message,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    timestamp: customTimestamp,
                    sender: customSender,
                    storeResult: false
                })
            )
        });

        StorageTypes.State memory neoToEvmState = messageBridgeProxy.neoToEvmState();
        bytes32 previousRoot = neoToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, messages);
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        // Store the message directly using the bridgeProxy.storeMessage method
        vm.prank(relayer);
        messageBridgeProxy.storeMessages(depositRoot, signatures, messages);

        // Retrieve the stored metadata and verify it
        AMBStorage.StoredMessage memory storedMessage = messageBridgeProxy.getEvmMessage(messages[0].nonce);
        AMBTypes.MetadataExecutable memory metadata = getExecutableMetadata(messages[0].nonce);
        bytes memory storedRawMessage = storedMessage.rawMessage;
        address storedSender = metadata.sender;
        uint256 storedTimestamp = metadata.timestamp;

        // Verify custom metadata fields
        assertEq(storedSender, customSender, "Custom metadata sender should match");
        assertEq(storedTimestamp, customTimestamp, "Custom metadata timestamp should match");

        // Verify raw message is stored correctly
        assertEq(storedRawMessage, message, "Message content should match");
    }

    function test_StoreAndExecuteMessageAfterWindowExpiry() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        // Create Call struct with testFunction encoded
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);

        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        uint256 nonce = 1;

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message
        storeMessage(nonce, message, "");

        // Get the current execution window from the bridge config
        AMBStorage.MessageConfig memory config = messageBridgeProxy.messageBridgeState().config;

        // Advance time past the execution window
        // 1 + 60 + 1
        vm.warp(block.timestamp + config.executionWindowSeconds + 1);

        // Attempt to execute the message after the window has expired - should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                MessageBridge.ExecutionWindowExpired.selector,
                block.timestamp - 1, // expiry time (current time - 1)
                block.timestamp // current time
            )
        );
        messageBridgeProxy.executeMessage(nonce);
    }

    // Tests for sending messages from EVM to N3

    function test_SendMessage_Success() public {
        // Prepare a test message
        bytes memory message = abi.encodePacked("Test message from EVM to N3");

        // Get the initial state
        StorageTypes.State memory evmToNeoState = messageBridgeProxy.evmToNeoState();
        uint256 initialNonce = evmToNeoState.nonce;
        uint256 expectedNonce = initialNonce + 1;
        bytes32 initialRoot = evmToNeoState.root;

        bytes memory encodedMetadata = abi.encode(
            AMBTypes.MetadataStoreOnly({
                msgType: AMBTypes.MessageType.STORE_ONLY,
                sender: address(this),
                timestamp: block.timestamp
            })
        );

        // Create the expected message hash
        bytes32 expectedMessageHash = MessageBridgeLib._hashMessageBridgeOp(expectedNonce, encodedMetadata, message);

        // Calculate the expected root
        bytes32 expectedRoot = BridgeLib._computeNewRoot(initialRoot, expectedMessageHash);

        // Set up event expectations
        vm.expectEmit(true, true, true, true);
        emit IMessageBridge.MessageSend(
            expectedNonce, // nonce
            address(this), // sender
            encodedMetadata, // encodedMetadata
            message, // message
            expectedMessageHash, // messageHash
            expectedRoot // newRoot
        );

        // Send the message with the required fee
        uint256 newNonce = messageBridgeProxy.sendMessage{value: messageFee}(message);
        assertEq(newNonce, expectedNonce, "Returned nonce should match expected");

        // Get the updated state
        StorageTypes.State memory updatedState = messageBridgeProxy.evmToNeoState();

        // Verify state changes
        assertEq(updatedState.nonce, expectedNonce, "Nonce should be incremented");
        assertEq(updatedState.root, expectedRoot, "Root should be updated correctly");
    }

    function test_SendMessage_InsufficientFee() public {
        // Prepare a test message
        bytes memory message = abi.encodePacked("Test message from EVM to N3");

        // Set insufficient fee
        uint256 insufficientFee = messageFee - 1;

        // Expect revert due to insufficient fee
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.InsufficientFee.selector, messageFee, insufficientFee));

        // Send the message with insufficient fee
        messageBridgeProxy.sendMessage{value: insufficientFee}(message);
    }

    function test_SendMessage_MessageTooLarge() public {
        // Get the message bridge config to know the max size
        AMBStorage.MessageConfig memory config = messageBridgeProxy.messageBridgeState().config;

        // Create a message that is larger than the max allowed size
        bytes memory largeMessage = new bytes(config.maxMessageSize + 1);
        for (uint256 i = 0; i < largeMessage.length; i++) {
            largeMessage[i] = 0xFF; // Fill with non-zero bytes
        }

        // Expect revert due to message being too large
        vm.expectRevert(
            abi.encodeWithSelector(MessageBridge.MessageTooLarge.selector, config.maxMessageSize, largeMessage.length)
        );

        // Send the oversized message
        messageBridgeProxy.sendMessage{value: messageFee}(largeMessage);
    }

    function test_SendMessage_ExactMaxMessageSize() public {
        // Get the message bridge config to know the max size
        AMBStorage.MessageConfig memory config = messageBridgeProxy.messageBridgeState().config;

        // Create a message that is exactly the max allowed size
        bytes memory exactSizeMessage = new bytes(config.maxMessageSize);
        for (uint256 i = 0; i < exactSizeMessage.length; i++) {
            exactSizeMessage[i] = 0xFF; // Fill with non-zero bytes
        }

        // Get the initial state
        StorageTypes.State memory evmToNeoState = messageBridgeProxy.evmToNeoState();
        uint256 initialNonce = evmToNeoState.nonce;
        uint256 expectedNonce = initialNonce + 1;

        // Send the message (should not revert)
        uint256 newNonce = messageBridgeProxy.sendMessage{value: messageFee}(exactSizeMessage);
        assertEq(newNonce, expectedNonce, "Returned nonce should match expected nonce");

        // Get the updated state
        StorageTypes.State memory updatedState = messageBridgeProxy.evmToNeoState();

        // Verify nonce increment
        assertEq(updatedState.nonce, expectedNonce, "Nonce should be incremented");
    }

    function test_SendMessage_WhenMessageBridgePaused() public {
        // Prepare a test message
        bytes memory message = abi.encodePacked("Test message from EVM to N3");

        // Pause the message bridge
        vm.prank(governor);
        messageBridgeProxy.pause();

        // Expect revert due to message bridge being paused
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.MessageBridgePaused.selector));

        // Attempt to send a message while the message bridge is paused
        messageBridgeProxy.sendMessage{value: messageFee}(message);
    }

    function test_SendMessage_ExcessFeeRefund() public {
        // Prepare a test message
        bytes memory message = abi.encodePacked("Test message from EVM to N3");

        // Send with excess fee
        uint256 excessFee = messageFee * 2;

        // Fund the owner account with enough ether to cover the excess fee
        vm.deal(owner, excessFee);

        // Track balance before sending
        uint256 balanceBefore = address(owner).balance;

        // Send the message with excess fee
        // Impersonate an EOA to send the message
        vm.prank(owner);
        messageBridgeProxy.sendMessage{value: excessFee}(message);

        // Track balance after sending
        uint256 balanceAfter = address(owner).balance;

        // Verify refund (initial balance - message fee = final balance)
        assertEq(balanceBefore - messageFee, balanceAfter, "Excess fee should be refunded");
    }

    function test_SendMessage_ExactFeeRequired_FromContract() public {
        // Create a test contract that will attempt to send a message
        TestContract testContract = new TestContract();

        // Prepare a test message
        bytes memory message = abi.encodePacked("Test message from contract");

        // Fund the test contract with ether
        (bool success,) = address(testContract).call{value: messageFee * 2}("");
        require(success, "Failed to fund test contract");

        // Try to send message from the contract with excess fee
        vm.prank(address(testContract));
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.ExactFeeRequired.selector, messageFee, messageFee * 2));
        messageBridgeProxy.sendMessage{value: messageFee * 2}(message);
    }

    function test_SendMessage_EmptyMessage() public {
        // Prepare an empty message
        bytes memory emptyMessage = new bytes(0);

        // Send the empty message
        messageBridgeProxy.sendMessage{value: messageFee}(emptyMessage);

        // Get the updated state
        StorageTypes.State memory updatedState = messageBridgeProxy.evmToNeoState();

        // Verify state changes (should succeed with empty message)
        assertEq(updatedState.nonce, 1, "Nonce should be incremented even with empty message");
    }

    function test_SendMessage_MultipleMessages() public {
        // Prepare multiple messages
        bytes memory message1 = abi.encodePacked("First message");
        bytes memory message2 = abi.encodePacked("Second message");
        bytes memory message3 = abi.encodePacked("Third message");

        // Send first message
        messageBridgeProxy.sendMessage{value: messageFee}(message1);

        // Get the state after first message
        StorageTypes.State memory state1 = messageBridgeProxy.evmToNeoState();
        assertEq(state1.nonce, 1, "Nonce should be 1 after first message");

        // Send second message
        messageBridgeProxy.sendMessage{value: messageFee}(message2);

        // Get the state after second message
        StorageTypes.State memory state2 = messageBridgeProxy.evmToNeoState();
        assertEq(state2.nonce, 2, "Nonce should be 2 after second message");

        // Send third message
        messageBridgeProxy.sendMessage{value: messageFee}(message3);

        // Get the state after third message
        StorageTypes.State memory state3 = messageBridgeProxy.evmToNeoState();
        assertEq(state3.nonce, 3, "Nonce should be 3 after third message");

        // Verify the roots are different
        assertTrue(state1.root != state2.root, "Root should change after each message");
        assertTrue(state2.root != state3.root, "Root should change after each message");
        assertTrue(state1.root != state3.root, "Root should change after each message");
    }

    // Helper function to receive ETH (needed for the refund test)
    receive() external payable {}

    // Tests for sendResultMessage function

    function test_SendResultMessage_Success() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        // Create a message with storeResult = true
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;

        // Store the message with storeResult = true
        storeMessageWithStoreResult(nonce, message, true);

        // Execute the message to generate execution results
        AMBTypes.Result memory executionResult = messageBridgeProxy.executeMessage(nonce);
        assertTrue(executionResult.success, "Message execution should succeed");

        // Get initial state for result message
        StorageTypes.State memory evmToNeoState = messageBridgeProxy.evmToNeoState();
        uint256 initialNonce = evmToNeoState.nonce;
        uint256 expectedNonce = initialNonce + 1;
        bytes32 initialRoot = evmToNeoState.root;

        // Create expected metadata for result message
        bytes memory expectedMetadata = abi.encode(
            AMBTypes.MetadataResult({
                msgType: AMBTypes.MessageType.RESULT,
                timestamp: block.timestamp,
                sender: address(this),
                relatedMessageNonce: nonce
            })
        );

        // Calculate expected values
        bytes memory resultData = abi.encode(executionResult);
        bytes32 expectedMessageHash = MessageBridgeLib._hashMessageBridgeOp(expectedNonce, expectedMetadata, resultData);
        bytes32 expectedRoot = BridgeLib._computeNewRoot(initialRoot, expectedMessageHash);

        // Expect the MessageSend event
        vm.expectEmit(true, true, true, true);
        emit IMessageBridge.MessageSend(
            expectedNonce, address(this), expectedMetadata, resultData, expectedMessageHash, expectedRoot
        );

        // Send the result message
        uint256 newNonce = messageBridgeProxy.sendResultMessage{value: messageFee}(nonce);
        assertEq(newNonce, expectedNonce, "Returned nonce should match expected");

        // Verify state changes
        StorageTypes.State memory updatedState = messageBridgeProxy.evmToNeoState();
        assertEq(updatedState.nonce, expectedNonce, "Nonce should be incremented");
        assertEq(updatedState.root, expectedRoot, "Root should be updated correctly");
    }

    function test_SendResultMessage_MessageNotFound() public {
        // Try to send result for a non-existent message
        uint256 nonExistentNonce = 999;

        vm.expectRevert(abi.encodeWithSelector(MessageBridge.MessageNotFound.selector, nonExistentNonce));
        messageBridgeProxy.sendResultMessage{value: messageFee}(nonExistentNonce);
    }

    function test_SendResultMessage_MessageExistsButNoStoredResult() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        // Create a message with storeResult = false (default)
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;

        // Store the message with storeResult = false
        storeMessage(nonce, message, "");

        // Execute the message
        AMBTypes.Result memory executionResult = messageBridgeProxy.executeMessage(nonce);
        assertTrue(executionResult.success, "Message execution should succeed");

        // Try to send result message - should fail because no result was stored
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.ResultNotFound.selector, nonce));
        messageBridgeProxy.sendResultMessage{value: messageFee}(nonce);
    }

    function test_SendResultMessage_InsufficientFee() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        // Create and store a message with storeResult = true
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;

        storeMessageWithStoreResult(nonce, message, true);
        messageBridgeProxy.executeMessage(nonce);

        // Try to send result with insufficient fee
        uint256 insufficientFee = messageFee - 1;
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.InsufficientFee.selector, messageFee, insufficientFee));
        messageBridgeProxy.sendResultMessage{value: insufficientFee}(nonce);
    }

    function test_SendResultMessage_WhenMessageBridgePaused() public {
        // Deploy test contract and execute a message with stored result
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;

        storeMessageWithStoreResult(nonce, message, true);
        messageBridgeProxy.executeMessage(nonce);

        // Pause the message bridge
        vm.prank(governor);
        messageBridgeProxy.pause();

        // Try to send result message while paused
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.MessageBridgePaused.selector));
        messageBridgeProxy.sendResultMessage{value: messageFee}(nonce);
    }

    function test_SendResultMessage_WhenSendingPaused() public {
        // Deploy test contract and execute a message with stored result
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;

        storeMessageWithStoreResult(nonce, message, true);
        messageBridgeProxy.executeMessage(nonce);

        // Pause sending
        vm.prank(governor);
        messageBridgeProxy.pauseSending();

        // Try to send result message while sending is paused
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.SendingPaused.selector));
        messageBridgeProxy.sendResultMessage{value: messageFee}(nonce);
    }

    function test_SendResultMessage_ExcessFeeRefund() public {
        // Deploy test contract and execute a message with stored result
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;

        storeMessageWithStoreResult(nonce, message, true);
        messageBridgeProxy.executeMessage(nonce);

        // Send with excess fee
        uint256 excessFee = messageFee * 2;
        vm.deal(owner, excessFee);

        uint256 balanceBefore = address(owner).balance;

        vm.prank(owner);
        messageBridgeProxy.sendResultMessage{value: excessFee}(nonce);

        uint256 balanceAfter = address(owner).balance;

        // Verify refund
        assertEq(balanceBefore - messageFee, balanceAfter, "Excess fee should be refunded");
    }

    function test_SendResultMessage_ExactFeeRequired_FromContract() public {
        // Deploy test contract and execute a message with stored result
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;

        storeMessageWithStoreResult(nonce, message, true);
        messageBridgeProxy.executeMessage(nonce);

        // Fund the test contract
        (bool success,) = address(testContract).call{value: messageFee * 2}("");
        require(success, "Failed to fund test contract");

        // Try to send result from contract with excess fee
        vm.prank(address(testContract));
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.ExactFeeRequired.selector, messageFee, messageFee * 2));
        messageBridgeProxy.sendResultMessage{value: messageFee * 2}(nonce);
    }

    function test_SendResultMessage_WithFailedExecutionResult() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        // Create a call that will fail
        bytes memory callData = abi.encodeWithSelector(TestContract.receivePayment.selector, 1 ether);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: true, target: address(testContract), value: 0, callData: callData}); // Mismatch: expects 1 ether but sends 0

        bytes memory message = abi.encode(call);
        uint256 nonce = 1;

        // Store the message with storeResult = true
        storeMessageWithStoreResult(nonce, message, true);

        // Execute the message (will fail but store the result)
        AMBTypes.Result memory executionResult = messageBridgeProxy.executeMessage(nonce);
        assertFalse(executionResult.success, "Message execution should fail");

        // Get initial state for result message
        StorageTypes.State memory evmToNeoState = messageBridgeProxy.evmToNeoState();
        uint256 initialNonce = evmToNeoState.nonce;
        uint256 expectedNonce = initialNonce + 1;

        // Send the result message (should work even with failed execution result)
        uint256 newNonce = messageBridgeProxy.sendResultMessage{value: messageFee}(nonce);
        assertEq(newNonce, expectedNonce, "Returned nonce should match expected");

        // Verify state changes
        StorageTypes.State memory updatedState = messageBridgeProxy.evmToNeoState();
        assertEq(updatedState.nonce, expectedNonce, "Nonce should be incremented");
    }

    function test_SendResultMessage_MultipleCalls() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        // Create and execute first message
        bytes memory callData1 = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call1 =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData1});
        bytes memory message1 = abi.encode(call1);
        uint256 nonce1 = 1;

        storeMessageWithStoreResult(nonce1, message1, true);
        messageBridgeProxy.executeMessage(nonce1);

        // Create and execute second message
        bytes memory callData2 = abi.encodeWithSelector(TestContract.receivePayment.selector, 1 ether);
        AMBTypes.Call memory call2 =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 1 ether, callData: callData2});
        bytes memory message2 = abi.encode(call2);
        uint256 nonce2 = nonce1 + 1;

        storeMessageWithStoreResult(nonce2, message2, true);
        messageBridgeProxy.executeMessage{value: 1 ether}(nonce2);

        // Get initial state
        StorageTypes.State memory initialState = messageBridgeProxy.evmToNeoState();

        // Send first result message
        messageBridgeProxy.sendResultMessage{value: messageFee}(nonce1);

        // Verify first result message was sent
        StorageTypes.State memory stateAfterFirst = messageBridgeProxy.evmToNeoState();
        assertEq(stateAfterFirst.nonce, initialState.nonce + 1, "Nonce should be incremented after first result");

        // Send second result message
        messageBridgeProxy.sendResultMessage{value: messageFee}(nonce2);

        // Verify second result message was sent
        StorageTypes.State memory stateAfterSecond = messageBridgeProxy.evmToNeoState();
        assertEq(stateAfterSecond.nonce, initialState.nonce + 2, "Nonce should be incremented after second result");

        // Verify roots are different
        assertTrue(initialState.root != stateAfterFirst.root, "Root should change after first result");
        assertTrue(stateAfterFirst.root != stateAfterSecond.root, "Root should change after second result");
    }

    function test_SendResultMessage_CanSendSameResultMultipleTimes() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        // Create and execute a message
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;

        storeMessageWithStoreResult(nonce, message, true);
        messageBridgeProxy.executeMessage(nonce);

        // Get initial state
        StorageTypes.State memory initialState = messageBridgeProxy.evmToNeoState();

        // Send result message first time
        messageBridgeProxy.sendResultMessage{value: messageFee}(nonce);

        // Verify first send worked
        StorageTypes.State memory stateAfterFirst = messageBridgeProxy.evmToNeoState();
        assertEq(stateAfterFirst.nonce, initialState.nonce + 1, "Nonce should be incremented after first send");

        // Send the same result message again (should work)
        messageBridgeProxy.sendResultMessage{value: messageFee}(nonce);

        // Verify second send worked
        StorageTypes.State memory stateAfterSecond = messageBridgeProxy.evmToNeoState();
        assertEq(stateAfterSecond.nonce, initialState.nonce + 2, "Nonce should be incremented after second send");
    }

    // Tests for getExecutableState function

    function test_GetExecutableState_MessageNotFound() public {
        // Try to get executable state for a non-existent message
        uint256 nonExistentNonce = 999;

        // Expect revert with MessageNotFound error
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.MessageNotFound.selector, nonExistentNonce));
        messageBridgeProxy.getExecutableState(nonExistentNonce);
    }

    function test_GetExecutableState_UnsupportedMessageType_StoreOnly() public {
        // Create and store a STORE_ONLY message (not executable)
        bytes memory message = abi.encodePacked("Test store-only message");
        uint256 nonce = 1;

        // Create message data with STORE_ONLY type
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({
            nonce: nonce,
            message: message,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataStoreOnly({
                    msgType: AMBTypes.MessageType.STORE_ONLY,
                    timestamp: block.timestamp,
                    sender: address(this)
                })
            )
        });

        // Store the STORE_ONLY message
        StorageTypes.State memory neoToEvmState = messageBridgeProxy.neoToEvmState();
        bytes32 previousRoot = neoToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, messages);
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        vm.prank(relayer);
        messageBridgeProxy.storeMessages(depositRoot, signatures, messages);

        // Try to get executable state for a STORE_ONLY message - should revert
        vm.expectRevert(
            abi.encodeWithSelector(MessageBridgeLib.UnsupportedMessageType.selector, AMBTypes.MessageType.STORE_ONLY)
        );
        messageBridgeProxy.getExecutableState(nonce);
    }

    function test_GetExecutableState_Success() public {
        // Create and store an EXECUTABLE message
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;

        // Store the executable message
        storeMessage(nonce, message, "");

        // Get executable state - should succeed
        AMBStorage.ExecutableState memory executableState = messageBridgeProxy.getExecutableState(nonce);

        // Verify the executable state
        assertFalse(executableState.executed, "Message should not be executed yet");
        assertTrue(executableState.expirationTimestamp > 0, "Expiration timestamp should be set");

        // Verify expiration timestamp is properly set (current time + execution window)
        AMBStorage.MessageConfig memory config = messageBridgeProxy.messageBridgeState().config;
        uint256 expectedExpiration = block.timestamp + config.executionWindowSeconds;
        assertEq(
            executableState.expirationTimestamp, expectedExpiration, "Expiration timestamp should match expected value"
        );
    }

    // test getResult with non-existent related nonce
    function test_GetResult_NonExistentRelatedNonce() public {
        // Try to get result for a non-existent related message nonce
        uint256 nonExistentNonce = 999;

        // Expect revert with MessageNotFound error
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.MessageNotFound.selector, nonExistentNonce));
        messageBridgeProxy.getResult(nonExistentNonce);
    }

    // test getResult with existing message but no stored result
    function test_GetResult_NoStoredResult() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;
        // Store the message without storeResult
        storeMessage(nonce, message, "");
        // Execute the message
        messageBridgeProxy.executeMessage(nonce);
        // Try to get result for the executed message - should revert
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.ResultNotFound.selector, nonce));
        messageBridgeProxy.getResult(nonce);
    }

    // test getResult with existing message and stored result
    function test_GetResult_Success() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;

        // Store the message with storeResult = true
        storeMessageWithStoreResult(nonce, message, true);

        // Execute the message
        AMBTypes.Result memory executionResult = messageBridgeProxy.executeMessage(nonce);
        assertTrue(executionResult.success, "Message execution should succeed");

        // Get the result for the executed message
        AMBTypes.Result memory result = messageBridgeProxy.getResult(nonce);

        // Verify the result matches the execution result
        assertEq(result.success, executionResult.success, "Execution result success should match");
        assertEq(result.returnData, executionResult.returnData, "Execution result return data should match");
    }

    function test_GetResult_SuccessWithFailedExecution() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.receivePayment.selector, 1 ether);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: true, target: address(testContract), value: 0, callData: callData}); // Mismatch: expects 1 ether but sends 0
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;
        // Store the message with storeResult = true
        storeMessageWithStoreResult(nonce, message, true);
        // Execute the message (will fail but store the result)
        AMBTypes.Result memory executionResult = messageBridgeProxy.executeMessage(nonce);
        assertFalse(executionResult.success, "Message execution should fail");
        // Get the result for the executed message
        AMBTypes.Result memory result = messageBridgeProxy.getResult(nonce);
        // Verify the result matches the execution result
        assertEq(result.success, executionResult.success, "Execution result success should match");
        assertEq(result.returnData, executionResult.returnData, "Execution result return data should match");
    }

    function test_GetResult_SuccessWithEmptyReturnData() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;
        // Store the message with storeResult = true
        storeMessageWithStoreResult(nonce, message, true);
        // Execute the message
        AMBTypes.Result memory executionResult = messageBridgeProxy.executeMessage(nonce);
        assertTrue(executionResult.success, "Message execution should succeed");
        // Get the result for the executed message
        AMBTypes.Result memory result = messageBridgeProxy.getResult(nonce);
        // Verify the result matches the execution result
        assertEq(result.success, executionResult.success, "Execution result success should match");
        assertEq(result.returnData, executionResult.returnData, "Execution result return data should match");
    }

    function test_GetResult_SuccessWithEmptyReturnDataAndStoreResultFalse() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;
        // Store the message with storeResult = false
        storeMessage(nonce, message, "");
        // Execute the message
        AMBTypes.Result memory executionResult = messageBridgeProxy.executeMessage(nonce);
        assertTrue(executionResult.success, "Message execution should succeed");
        // Expect revert when trying to get result for a message that did not store result
        vm.expectRevert(abi.encodeWithSelector(MessageBridge.ResultNotFound.selector, nonce));
        messageBridgeProxy.getResult(nonce);
    }

    // test getResult with failWithPanic() method from TestContract
    function test_GetResult_WithPanicExecution() public {
        // Deploy test contract
        TestContract testContract = new TestContract();
        bytes memory callData = abi.encodeWithSelector(TestContract.failWithPanic.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: true, target: address(testContract), value: 0, callData: callData});
        bytes memory message = abi.encode(call);
        uint256 nonce = 1;
        // Store the message with storeResult = true
        storeMessageWithStoreResult(nonce, message, true);
        // Execute the message (will panic)
        AMBTypes.Result memory executionResult = messageBridgeProxy.executeMessage(nonce);
        assertFalse(executionResult.success, "Message execution should fail with panic");
        // Get the result for the executed message
        AMBTypes.Result memory result = messageBridgeProxy.getResult(nonce);
        // Verify the result matches the execution result
        assertEq(result.success, executionResult.success, "Execution result success should match");
        assertEq(result.returnData, executionResult.returnData, "Execution result return data should match");
    }

    // Message execution tests with refunds

    function test_ExecuteMessage_FailureWithRefund_EOA() public {
        // Deploy a contract that always fails
        FailingContract failingContract = new FailingContract();
        address eoa = makeAddr("eoa");
        vm.deal(eoa, 10 ether);

        uint256 testValue = 1 ether;

        // Create message that will fail but allows failure
        bytes memory messageData = abi.encode(
            AMBTypes.Call({
                allowFailure: true,
                target: address(failingContract),
                value: testValue,
                callData: abi.encodeWithSignature("alwaysFail()")
            })
        );

        storeMessage(1, messageData, "");

        uint256 balanceBefore = eoa.balance;

        // EOA executes message - should get refund
        vm.prank(eoa);
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: testValue}(1);

        // Verify call failed but message execution succeeded
        assertFalse(result.success, "Target call should have failed");
        assertTrue(messageBridgeProxy.getExecutableState(1).executed, "Message should be marked as executed");

        // Verify EOA got refunded
        uint256 balanceAfter = eoa.balance;
        assertEq(balanceAfter, balanceBefore, "EOA should be refunded");
    }

    function test_ExecuteMessage_FailureWithRefund_Contract() public {
        // Deploy contracts for testing
        FailingContract failingContract = new FailingContract();
        RefundReceiver refundReceiver = new RefundReceiver();
        vm.deal(address(refundReceiver), 10 ether);

        uint256 testValue = 1 ether;

        // Create message that will fail but allows failure
        bytes memory messageData = abi.encode(
            AMBTypes.Call({
                allowFailure: true,
                target: address(failingContract),
                value: testValue,
                callData: abi.encodeWithSignature("alwaysFail()")
            })
        );

        storeMessage(1, messageData, "");

        uint256 balanceBefore = address(refundReceiver).balance;
        uint256 refundCountBefore = refundReceiver.refundCount();

        // Contract executes message - should get refund
        vm.prank(address(refundReceiver));
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: testValue}(1);

        // Verify call failed but message execution succeeded
        assertFalse(result.success, "Target call should have failed");
        assertTrue(messageBridgeProxy.getExecutableState(1).executed, "Message should be marked as executed");

        // Verify contract got refunded
        uint256 balanceAfter = address(refundReceiver).balance;
        uint256 refundCountAfter = refundReceiver.refundCount();

        assertEq(balanceAfter, balanceBefore, "Contract should be refunded");
        assertEq(refundCountAfter, refundCountBefore + 1, "Refund should be tracked");
    }

    function test_ExecuteMessage_FailureNoRefund_ZeroValue() public {
        // Deploy a contract that always fails
        FailingContract failingContract = new FailingContract();
        address eoa = makeAddr("eoa");
        vm.deal(eoa, 10 ether);

        // Create message with zero value that will fail but allows failure
        bytes memory messageData = abi.encode(
            AMBTypes.Call({
                allowFailure: true,
                target: address(failingContract),
                value: 0,
                callData: abi.encodeWithSignature("alwaysFail()")
            })
        );

        storeMessage(1, messageData, "");

        uint256 balanceBefore = eoa.balance;

        // Execute with zero value - no refund needed
        vm.prank(eoa);
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage{value: 0}(1);

        // Verify call failed but message execution succeeded
        assertFalse(result.success, "Target call should have failed");
        assertTrue(messageBridgeProxy.getExecutableState(1).executed, "Message should be marked as executed");

        // Balance should be unchanged (no refund needed)
        uint256 balanceAfter = eoa.balance;
        assertEq(balanceAfter, balanceBefore, "No balance change expected for zero value");
    }

    function test_ExecuteMessage_RefundFails_RevertsTransaction() public {
        // Deploy contracts for testing
        FailingContract failingContract = new FailingContract();
        NonPayableContract nonPayableContract = new NonPayableContract();
        vm.deal(address(nonPayableContract), 10 ether);

        uint256 testValue = 1 ether;

        // Create message that will fail but allows failure
        bytes memory messageData = abi.encode(
            AMBTypes.Call({
                allowFailure: true,
                target: address(failingContract),
                value: testValue,
                callData: abi.encodeWithSignature("alwaysFail()")
            })
        );

        storeMessage(1, messageData, "");

        // Non-payable contract tries to execute - refund should fail
        vm.prank(address(nonPayableContract));
        vm.expectRevert(abi.encodeWithSelector(ExecutionManager.RefundFailed.selector));
        messageBridgeProxy.executeMessage{value: testValue}(1);

        // Message should NOT be marked as executed due to refund failure
        assertFalse(
            messageBridgeProxy.getExecutableState(1).executed, "Message should not be executed due to refund failure"
        );
    }

    function test_ExecuteMessage_AllowFailureFalse_RevertsTransaction() public {
        // Deploy a contract that always fails
        FailingContract failingContract = new FailingContract();
        address eoa = makeAddr("eoa");
        vm.deal(eoa, 10 ether);

        uint256 testValue = 1 ether;

        // Create message that will fail and does NOT allow failure
        bytes memory messageData = abi.encode(
            AMBTypes.Call({
                allowFailure: false,
                target: address(failingContract),
                value: testValue,
                callData: abi.encodeWithSelector(FailingContract.alwaysFail.selector)
            })
        );

        storeMessage(1, messageData, "");
        // Execute should revert entirely - no refund attempt
        vm.prank(eoa);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExecutionManager.ExecutionFailed.selector, abi.encodeWithSelector(FailingContract.AlwaysFails.selector)
            )
        );
        messageBridgeProxy.executeMessage{value: testValue}(1);

        // Message should NOT be marked as executed
        assertFalse(messageBridgeProxy.getExecutableState(1).executed, "Message should not be executed");
    }

    function test_ExecuteMessage_ValueMismatch_RefundScenario() public {
        FailingContract failingContract = new FailingContract();
        address eoa = makeAddr("eoa");
        vm.deal(eoa, 10 ether);

        uint256 testValue = 1 ether;

        bytes memory messageData = abi.encode(
            AMBTypes.Call({
                allowFailure: false,
                target: address(failingContract),
                value: testValue,
                callData: abi.encodeWithSignature("alwaysFail()")
            })
        );

        storeMessage(1, messageData, "");

        // Send wrong value (less than required) - should revert with ValueMismatch
        vm.prank(eoa);
        vm.expectRevert(abi.encodeWithSelector(ExecutionManager.ValueMismatch.selector, testValue / 2, testValue));
        messageBridgeProxy.executeMessage{value: testValue / 2}(1);

        // Send wrong value (greater than required) - should revert with ValueMismatch
        vm.prank(eoa);
        vm.expectRevert(abi.encodeWithSelector(ExecutionManager.ValueMismatch.selector, testValue * 2, testValue));
        messageBridgeProxy.executeMessage{value: testValue * 2}(1);
    }

    function test_ExecuteMessage_MultipleRefundScenarios() public {
        // Deploy test contracts
        FailingContract failingContract = new FailingContract();
        RefundReceiver refundReceiver = new RefundReceiver();
        address eoa = makeAddr("eoa");

        vm.deal(address(refundReceiver), 10 ether);
        vm.deal(eoa, 10 ether);

        // Message 1: allowFailure = true, should refund
        bytes memory messageData1 = abi.encode(
            AMBTypes.Call({
                allowFailure: true,
                target: address(failingContract),
                value: 0.5 ether,
                callData: abi.encodeWithSignature("alwaysFail()")
            })
        );

        // Message 2: allowFailure = true, zero value, no refund needed
        bytes memory messageData2 = abi.encode(
            AMBTypes.Call({
                allowFailure: true,
                target: address(failingContract),
                value: 0,
                callData: abi.encodeWithSignature("alwaysFail()")
            })
        );

        // Store messages
        storeMessage(1, messageData1, "");
        storeMessage(2, messageData2, "");

        // Execute first message from refund receiver
        uint256 balanceBefore = address(refundReceiver).balance;
        vm.prank(address(refundReceiver));
        messageBridgeProxy.executeMessage{value: 0.5 ether}(1);

        // Verify refund received
        assertEq(address(refundReceiver).balance, balanceBefore, "Should receive refund");
        (uint256 refundCount,) = refundReceiver.getRefundInfo();
        assertEq(refundCount, 1, "Should have one refund");

        // Execute second message from EOA
        uint256 eoaBalanceBefore = eoa.balance;
        vm.prank(eoa);
        messageBridgeProxy.executeMessage{value: 0}(2);

        // Verify no balance change for zero value
        assertEq(eoa.balance, eoaBalanceBefore, "EOA balance should remain unchanged");

        // Verify refund receiver didn't get another refund
        (uint256 finalRefundCount,) = refundReceiver.getRefundInfo();
        assertEq(finalRefundCount, 1, "Should still have only one refund");
    }

    // Test to check executing nonce is accessible during execution
    function test_ExecuteMessage_ExecutingNonceAccessible() public {
        // Deploy the test contract that can capture the executing nonce
        ExecutingNonceTestContract nonceTestContract = new ExecutingNonceTestContract(address(executionManager));

        // Create a message that calls the captureExecutingNonce function
        bytes memory callData = abi.encodeWithSelector(ExecutingNonceTestContract.captureExecutingNonce.selector);
        AMBTypes.Call memory call =
            AMBTypes.Call({allowFailure: false, target: address(nonceTestContract), value: 0, callData: callData});

        bytes memory message = abi.encode(call);
        uint256 expectedNonce = 1;

        // Store the message
        storeMessage(expectedNonce, message, "");

        // Verify the executing nonce is 0 before execution (not executing anything)
        uint256 nonceBefore = executionManager.executingNonce();
        assertEq(nonceBefore, 0, "Executing nonce should be 0 when not executing");

        // Expect the NonceCapture event to be emitted with the correct nonce
        vm.expectEmit(true, true, true, true, address(nonceTestContract));
        emit ExecutingNonceTestContract.NonceCapture(expectedNonce, address(executionManager));

        // Execute the message
        AMBTypes.Result memory result = messageBridgeProxy.executeMessage(expectedNonce);

        // Verify execution was successful
        assertTrue(result.success, "Message execution should succeed");

        // Verify the executing nonce is back to 0 after execution
        uint256 nonceAfter = executionManager.executingNonce();
        assertEq(nonceAfter, 0, "Executing nonce should be 0 after execution completes");

        // Verify the contract captured the correct nonce during execution
        uint256 capturedNonce = nonceTestContract.getCapturedNonce();
        assertEq(capturedNonce, expectedNonce, "Contract should have captured the executing nonce");

        // Decode the return data to verify the function returned the correct nonce
        uint256 returnedNonce = abi.decode(result.returnData, (uint256));
        assertEq(returnedNonce, expectedNonce, "Function should have returned the executing nonce");
    }
}

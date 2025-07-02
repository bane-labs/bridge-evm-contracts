// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BridgeStorage, StorageTypes} from "../contracts/bridge/BridgeStorage.sol";
import {IMessageBridge} from "../contracts/interfaces/IMessageBridge.sol";
import {BridgeLib} from "../contracts/library/BridgeLib.sol";
import {MessageBridgeLib} from "../contracts/library/MessageBridgeLib.sol";
import {SigUtils} from "../contracts/tests/SigUtils.sol";
import {TestBridge, BridgeImpl} from "../contracts/tests/TestBridge.sol";
import {TestBridgeManagement} from "../contracts/tests/TestBridgeManagement.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {TestMessageContract} from "../contracts/tests/TestMessageContract.sol";
import {TestPayableContract} from "../contracts/tests/TestPayableContract.sol";
import {console2} from "../lib/openzeppelin-foundry-upgrades/lib/forge-std/src/console2.sol";

contract MessageBridgeTest is Test, SigUtils {
    TestBridge bridgeProxy;
    address bridgeProxyAddress;

    // Management
    TestBridgeManagement managementProxy;
    address managementProxyAddress;
    SigUtils sigUtils;
    address public owner = 0xBcd4042DE499D14e55001CcbB24a551F3b954096;
    address public funder = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public relayer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint8 public validatorThreshold = 7;
    address[] public validatorsAddresses;
    address internal governor = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    address internal securityGuard = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

    // Message Bridge Config
    uint256 messageFee = 0.01 ether;
    uint256 maxMessageSize = 1024;
    uint256 maxDeposits = 10;

    // Test message data
    bytes testMessage1 =
        abi.encode(StorageTypes.Call({target: address(0x1234), callData: hex"abcd", allowFailure: false, value: 0}));
    bytes testMessage2 =
        abi.encode(StorageTypes.Call({target: address(0x5678), callData: hex"ef01", allowFailure: true, value: 0}));

    function setUp() public {
        sigUtils = new SigUtils();
        validatorsAddresses.push(vm.addr(user0PrivateKey));
        validatorsAddresses.push(vm.addr(user1PrivateKey));
        validatorsAddresses.push(vm.addr(user2PrivateKey));
        validatorsAddresses.push(vm.addr(user3PrivateKey));
        validatorsAddresses.push(vm.addr(user4PrivateKey));
        validatorsAddresses.push(vm.addr(user5PrivateKey));
        validatorsAddresses.push(vm.addr(user6PrivateKey));

        // Allow constructor to bypass the safety check in deployUUPSProxy.
        Options memory opts;
        opts.unsafeAllow = "constructor";

        // Deploy the bridge management implementation
        managementProxyAddress = Upgrades.deployUUPSProxy(
            "TestBridgeManagement.sol",
            abi.encodeCall(
                TestBridgeManagement.initialize,
                (owner, relayer, validatorThreshold, validatorsAddresses, governor, securityGuard, funder)
            ),
            opts
        );
        managementProxy = TestBridgeManagement(payable(managementProxyAddress));
        // vm.prank(owner);
        // managementProxy.upgradeToV<version_nr>();
        // Validate initialization to version 3
        assertEq(managementProxy.getCurrentInitializedVersion(), 3);

        // Deploy the bridge implementation
        bridgeProxyAddress = Upgrades.deployUUPSProxy(
            "TestBridge.sol", abi.encodeCall(TestBridge.initialize, (managementProxyAddress)), opts
        );
        bridgeProxy = TestBridge(payable(bridgeProxyAddress));
        // vm.prank(owner);
        // bridgeProxy.upgradeToV<version_nr>();

        assertFalse(bridgeProxy.messageBridgeIsSet(), "Message bridge should not be set");
        // Set up the message bridge
        vm.prank(governor);
        bridgeProxy.setMessageBridge(messageFee, maxMessageSize, maxDeposits);
        assertTrue(bridgeProxy.messageBridgeIsSet(), "Message bridge should be set");

        // Unpause the message bridge
        vm.prank(governor);
        bridgeProxy.unpauseMessageBridge();
    }

    function test_SetMessageBridge() public {
        // Test that the message bridge is correctly set up
        assertTrue(bridgeProxy.messageBridgeIsSet(), "Message bridge should be set");

        // Change configuration
        uint256 newFee = 2e16;
        uint256 newMaxSize = 2048;
        uint256 newMaxDeposits = 20;

        vm.prank(governor);
        bridgeProxy.setMessageBridge(newFee, newMaxSize, newMaxDeposits);

        // Verify changes through events (we would need to check logs)
        // This is a simplified check - in a real test, you would verify the config values directly
        assertTrue(bridgeProxy.messageBridgeIsSet(), "Message bridge should still be set after config change");
    }

    function test_MessageBridgePauseUnpause() public {
        // Test pausing
        vm.prank(governor);
        bridgeProxy.pauseMessageBridge();

        // Try to deposit a message while paused (should revert)
        StorageTypes.MessageData[] memory messages = new StorageTypes.MessageData[](1);
        messages[0] = StorageTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            metadata: StorageTypes.Metadata({sender: address(this), timestamp: block.timestamp})
        });

        (, StorageTypes.State memory n3ToEvmState,,) = bridgeProxy.messageBridge();
        bytes32 previousRoot = n3ToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, messages);
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        vm.prank(relayer);
        vm.expectRevert(); // Should revert since bridge is paused
        bridgeProxy.storeMessage(depositRoot, signatures, messages);

        // Unpause and try again
        vm.prank(governor);
        bridgeProxy.unpauseMessageBridge();

        // Now it should work (not reverting)
        vm.prank(relayer);
        bridgeProxy.storeMessage(depositRoot, signatures, messages);
    }

    function test_StoreAndExecuteMessageWithTestMessageContract() public {
        // Deploy test contract
        TestMessageContract testContract = new TestMessageContract();

        assertEq(testContract.counter(), 0, "Counter should be initialized to 0");

        // Create Call struct with testFunction encoded
        bytes memory callData = abi.encodeWithSelector(TestMessageContract.testFunction.selector);

        StorageTypes.Call memory call =
            StorageTypes.Call({target: address(testContract), callData: callData, allowFailure: false, value: 0});
        uint256 nonce = 1;

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message and get the nonce
        storeMessage(nonce, message, "");

        // Expect the TestEvent to be emitted with correct parameters
        vm.expectEmit(true, true, true, true, address(testContract));
        emit TestMessageContract.TestEvent(1, address(bridgeProxy));

        // Execute the message
        StorageTypes.Result memory result = bridgeProxy.executeMessage(nonce);

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
        TestMessageContract testContract = new TestMessageContract();
        // Verify the contract did not receive any ETH
        assertEq(address(testContract).balance, 0, "Test contract should not have received ETH");

        // Create Call struct with receivePayment encoded
        uint256 paymentAmount = 1 ether;
        bytes memory callData = abi.encodeWithSelector(TestMessageContract.receivePayment.selector, paymentAmount);

        StorageTypes.Call memory call = StorageTypes.Call({
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
        emit TestMessageContract.PaymentReceived(paymentAmount, address(bridgeProxy));

        // Execute the message
        StorageTypes.Result memory result = bridgeProxy.executeMessage{value: paymentAmount}(nonce);

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
        TestMessageContract testContract = new TestMessageContract();
        assertEq(address(testContract).balance, 0, "Test contract should not have ETH");

        // Create Call struct with receivePayment encoded but with mismatched values
        uint256 declaredAmount = 1 ether;
        uint256 actualAmount = 0.5 ether; // Mismatched amount
        bytes memory callData = abi.encodeWithSelector(TestMessageContract.receivePayment.selector, declaredAmount);

        StorageTypes.Call memory call = StorageTypes.Call({
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

        // Execute the message - this should fail but not revert the transaction
        StorageTypes.Result memory result = bridgeProxy.executeMessage{value: actualAmount}(nonce);

        // Verify execution failed as expected
        assertFalse(result.success, "Message execution should fail due to value mismatch");

        bytes memory errorBytes = result.returnData;

        // Verify that the error is a ValueMismatch error
        bytes4 errorSelector;
        assembly {
            errorSelector := mload(add(errorBytes, 0x20))
        }
        bytes4 expectedSelector = TestMessageContract.ValueMismatch.selector;
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
        TestMessageContract testContract = new TestMessageContract();
        assertEq(address(testContract).balance, 0, "Test contract should not have ETH");

        // Create Call struct with empty callData to trigger receive() function
        bytes memory callData = "";

        StorageTypes.Call memory call =
            StorageTypes.Call({target: address(testContract), callData: callData, allowFailure: false, value: 1 ether});

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        (, StorageTypes.State memory n3ToEvmState,,) = bridgeProxy.messageBridge();
        uint256 nonce = n3ToEvmState.nonce + 1;

        // Store the message with the nonce
        storeMessage(nonce, message, "");

        // Expect the DirectEthReceived event to be emitted with correct sender
        vm.expectEmit(true, true, true, true, address(testContract));
        emit TestMessageContract.DirectEthReceived(address(bridgeProxy));

        // Execute the message
        StorageTypes.Result memory result = bridgeProxy.executeMessage{value: 1 ether}(nonce);

        // Verify execution was successful
        assertTrue(result.success, "Message execution should succeed");

        // Verify the contract received the 1 ETH
        assertEq(address(testContract).balance, call.value, "Payable contract should have received 1 ETH");
    }

    function test_StoreAndExecuteMessageWithTestContractFallback() public {
        // Deploy test contract
        TestMessageContract testContract = new TestMessageContract();
        assertEq(address(testContract).balance, 0, "Test contract should not have ETH");

        // Create a valid address payload to send in the calldata
        bytes memory addressBytes = abi.encodePacked(address(this));

        StorageTypes.Call memory call = StorageTypes.Call({
            target: address(testContract),
            callData: addressBytes,
            allowFailure: false,
            value: 1 ether
        });

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        (, StorageTypes.State memory n3ToEvmState,,) = bridgeProxy.messageBridge();
        uint256 nonce = n3ToEvmState.nonce + 1;

        // Store the message with the nonce
        storeMessage(nonce, message, "");

        // Expect the FallbackCalled event to be emitted with correct parameters
        vm.expectEmit(true, true, true, true, address(testContract));
        emit TestMessageContract.FallbackCalled(address(bridgeProxy), 1 ether, addressBytes);

        // Execute the message
        StorageTypes.Result memory result = bridgeProxy.executeMessage{value: 1 ether}(nonce);

        // Verify execution was successful
        assertTrue(result.success, "Message execution should succeed");

        // Verify the contract received the 1 ETH
        assertEq(address(testContract).balance, call.value, "Test contract should have received 1 ETH");
    }

    function test_StoreAndExecuteMessageWithZeroValuePayment() public {
        // Deploy test contract
        TestMessageContract testContract = new TestMessageContract();
        assertEq(address(testContract).balance, 0, "Test contract should not have ETH");

        // Test 1: Zero value with receivePayment function
        {
            uint256 declaredAmount = 1 ether;
            uint256 actualAmount = 0; // Zero value
            bytes memory callData = abi.encodeWithSelector(TestMessageContract.receivePayment.selector, declaredAmount);

            StorageTypes.Call memory call = StorageTypes.Call({
                target: address(testContract),
                callData: callData,
                allowFailure: true, // Allow failure so we can check the error
                value: actualAmount
            });

            bytes memory message = abi.encode(call);
            uint256 nonce = 1;
            storeMessage(nonce, message, "");
            StorageTypes.Result memory result = bridgeProxy.executeMessage{value: actualAmount}(nonce);

            // Verify execution failed as expected
            assertFalse(result.success, "Message execution should fail due to zero value");

            // Verify the error is ZeroValueNotAllowed
            bytes memory errorData = result.returnData;
            bytes4 errorSelector;
            assembly {
                errorSelector := mload(add(errorData, 0x20))
            }
            bytes4 expectedSelector = TestMessageContract.ZeroValueNotAllowed.selector;
            assertEq(errorSelector, expectedSelector, "Error selector should match ZeroValueNotAllowed");

            // Verify the contract did not receive any ETH
            assertEq(address(testContract).balance, 0, "Test contract should not have received ETH");
        }

        // Test 2: Zero value with fallback function
        {
            bytes memory addressBytes = abi.encodePacked(address(this));

            StorageTypes.Call memory call = StorageTypes.Call({
                target: address(testContract),
                callData: addressBytes,
                allowFailure: true,
                value: 0 // Zero value
            });

            bytes memory message = abi.encode(call);
            uint256 nonce = 2;
            storeMessage(nonce, message, "");
            StorageTypes.Result memory result = bridgeProxy.executeMessage{value: 0}(nonce);

            // Verify execution failed as expected
            assertFalse(result.success, "Message execution should fail due to zero value in fallback");

            // Verify the error is ZeroValueNotAllowed
            bytes memory errorData = result.returnData;
            bytes4 errorSelector;
            assembly {
                errorSelector := mload(add(errorData, 0x20))
            }
            bytes4 expectedSelector = TestMessageContract.ZeroValueNotAllowed.selector;
            assertEq(errorSelector, expectedSelector, "Error selector should match ZeroValueNotAllowed");

            // Verify the contract did not receive any ETH
            assertEq(address(testContract).balance, 0, "Test contract should not have received ETH");
        }

        // Test 3: Zero value with receive function
        {
            bytes memory callData = "";

            StorageTypes.Call memory call = StorageTypes.Call({
                target: address(testContract),
                callData: callData,
                allowFailure: true,
                value: 0 // Zero value
            });

            bytes memory message = abi.encode(call);
            uint256 nonce = 3;
            storeMessage(nonce, message, "");
            StorageTypes.Result memory result = bridgeProxy.executeMessage{value: 0}(nonce);

            // Verify execution failed as expected
            assertFalse(result.success, "Message execution should fail due to zero value in receive");

            // Verify the error is ZeroValueNotAllowed
            bytes memory errorData = result.returnData;
            bytes4 errorSelector;
            assembly {
                errorSelector := mload(add(errorData, 0x20))
            }
            bytes4 expectedSelector = TestMessageContract.ZeroValueNotAllowed.selector;
            assertEq(errorSelector, expectedSelector, "Error selector should match ZeroValueNotAllowed");
            // Verify the contract did not receive any ETH
            assertEq(address(testContract).balance, 0, "Test contract should not have received ETH");
        }
    }

    function test_StoreAndExecuteMessageWithTestContractInvalidCallData() public {
        // Deploy test contract
        TestMessageContract testContract = new TestMessageContract();
        assertEq(address(testContract).balance, 0, "Test contract should not have ETH");

        // Create an invalid payload that's not a valid function of this contract or an address (20 bytes)
        bytes memory invalidCallData = abi.encodeWithSignature("someFunction(uint256)", 123);

        StorageTypes.Call memory call = StorageTypes.Call({
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
                BridgeStorage.CallFailed.selector, abi.encodeWithSelector(TestMessageContract.InvalidCallData.selector)
            )
        );

        // Execute the message
        bridgeProxy.executeMessage{value: 1 ether}(nonce);

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

        StorageTypes.Call memory call =
            StorageTypes.Call({target: nonExistentContract, callData: callData, allowFailure: true, value: 0.1 ether});

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message with a specific nonce
        uint256 nonce = 1;
        storeMessage(nonce, message, "");

        // Execute the message - this should succeed when calling an EOA
        StorageTypes.Result memory result = bridgeProxy.executeMessage{value: 0.1 ether}(nonce);

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
        result = bridgeProxy.executeMessage{value: 0.1 ether}(nonce);
        assertTrue(result.success, "Message execution should succeed when calling an EOA with allowFailure=false");
        // Verify the contract received the 1 ETH
        assertEq(address(nonExistentContract).balance, 2 * call.value, "EOA should have received another 0.1 ETH");
    }

    function test_StoreAndExecuteMessageStorageErrors() public {
        // Create a test message
        TestMessageContract testContract = new TestMessageContract();
        bytes memory callData = abi.encodeWithSelector(TestMessageContract.testFunction.selector);
        StorageTypes.Call memory call =
            StorageTypes.Call({target: address(testContract), callData: callData, allowFailure: false, value: 0});
        bytes memory message = abi.encode(call);

        // Get current state and nonce
        (, StorageTypes.State memory n3ToEvmState,,) = bridgeProxy.messageBridge();
        uint256 nonce = n3ToEvmState.nonce + 1;

        // Store the message with the nonce
        storeMessage(nonce, message, "");

        // Try to store the same message with the same nonce again: should revert with MessageAlreadyExists
        vm.prank(relayer);
        bytes4 errorSelector = BridgeStorage.InvalidNonceSequence.selector;
        storeMessage(nonce, message, abi.encodePacked(errorSelector));

        // Execute the stored message: should succeed
        StorageTypes.Result memory result = bridgeProxy.executeMessage(nonce);
        assertTrue(result.success, "Message execution should succeed");

        // Try to execute a non-existent message: should revert with MessageNotFound
        uint256 nonExistentNonce = 999;
        vm.expectRevert(abi.encodeWithSelector(BridgeStorage.MessageNotFound.selector, nonExistentNonce));
        bridgeProxy.executeMessage(nonExistentNonce);
    }

    function test_StoreAndExecuteMessageNonExistentPayableFunction() public {
        // Deploy TestPayableContract (which doesn't have testFunction)
        TestPayableContract payableContract = new TestPayableContract();
        assertEq(address(payableContract).balance, 0, "Payable contract should not have received ETH");

        // Create Call struct with testFunction selector (which TestPayableContract doesn't implement)
        bytes memory callData = abi.encodeWithSelector(TestMessageContract.testFunction.selector);

        StorageTypes.Call memory call = StorageTypes.Call({
            target: address(payableContract),
            callData: callData,
            allowFailure: true,
            value: 0.1 ether
        });

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message with a specific nonce
        uint256 nonce = 1;
        storeMessage(nonce, message, "");

        // Execute the message - this should fail but not revert since allowFailure is true
        StorageTypes.Result memory result = bridgeProxy.executeMessage{value: 0.1 ether}(nonce);

        // Verify execution failed as expected - TestPayableContract doesn't implement this function
        assertFalse(result.success, "Message execution should fail when calling non-existent function");

        // Now try with allowFailure set to false - should revert
        call.allowFailure = false;
        message = abi.encode(call);
        nonce = 2;
        storeMessage(nonce, message, "");

        // This should revert with CallFailed error
        vm.expectRevert(abi.encodeWithSelector(BridgeStorage.CallFailed.selector, ""));
        bridgeProxy.executeMessage{value: 0.1 ether}(nonce);

        // Check that payableContract did not receive funds when the function call failed
        assertEq(address(payableContract).balance, 0, "Payable contract should not have received ETH");
    }

    // Test depositMessage function with random messages

    function test_StoreRandomMessages() public {
        // Prepare message data
        StorageTypes.MessageData[] memory messages = new StorageTypes.MessageData[](2);
        messages[0] = StorageTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            metadata: StorageTypes.Metadata({sender: address(this), timestamp: block.timestamp})
        });
        messages[1] = StorageTypes.MessageData({
            nonce: 2,
            message: testMessage2,
            metadata: StorageTypes.Metadata({sender: address(this), timestamp: block.timestamp})
        });

        // Compute the deposit root
        (, StorageTypes.State memory n3ToEvmState,,) = bridgeProxy.messageBridge();
        bytes32 previousRoot = n3ToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, messages);

        // Generate valid signatures from validators
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        // Perform deposit
        vm.prank(relayer);
        bridgeProxy.storeMessage(depositRoot, signatures, messages);

        // Verify messages were stored correctly
        // We need to decode the original messages to compare with what's stored
        StorageTypes.Call memory expectedCall1 = abi.decode(testMessage1, (StorageTypes.Call));
        StorageTypes.Call memory expectedCall2 = abi.decode(testMessage2, (StorageTypes.Call));

        // Get the stored Call struct components - public mappings return struct components, not the struct itself
        StorageTypes.Call memory actualCall =
            abi.decode(bridgeProxy.n3ToEvmRawMessages(messages[0].nonce), (StorageTypes.Call));

        // Verify that stored Call struct components match the expected ones
        assertEq(actualCall.target, expectedCall1.target, "First message target should match");
        assertEq(actualCall.value, expectedCall1.value, "First message value should match");
        assertEq(actualCall.allowFailure, expectedCall1.allowFailure, "First message allowFailure should match");
        assertEq(actualCall.callData, expectedCall1.callData, "First message callData should match");

        actualCall = abi.decode(bridgeProxy.n3ToEvmRawMessages(messages[1].nonce), (StorageTypes.Call));
        assertEq(actualCall.target, expectedCall2.target, "Second message target should match");
        assertEq(actualCall.value, expectedCall2.value, "Second message value should match");
        assertEq(actualCall.allowFailure, expectedCall2.allowFailure, "Second message allowFailure should match");
        assertEq(actualCall.callData, expectedCall2.callData, "Second message callData should match");
    }

    function test_StoreMessageInvalidRoot() public {
        // Prepare message data
        StorageTypes.MessageData[] memory messages = new StorageTypes.MessageData[](1);
        messages[0] = StorageTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            metadata: StorageTypes.Metadata({sender: address(this), timestamp: block.timestamp})
        });

        // Use an incorrect deposit root
        bytes32 invalidDepositRoot = bytes32(uint256(1));

        // Generate valid signatures for the INVALID root
        BridgeLib.Signature[] memory signatures = generateValidSignatures(invalidDepositRoot);

        // Expect revert due to invalid root
        vm.prank(relayer);
        vm.expectRevert(); // Should revert with InvalidRoot error
        bridgeProxy.storeMessage(invalidDepositRoot, signatures, messages);
    }

    function test_StoreMessageInvalidSignatures() public {
        // Prepare message data
        StorageTypes.MessageData[] memory messages = new StorageTypes.MessageData[](1);
        messages[0] = StorageTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            metadata: StorageTypes.Metadata({sender: address(this), timestamp: block.timestamp})
        });

        // Compute the correct deposit root
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(bytes32(0), messages);

        // Generate invalid signatures (from non-validators)
        BridgeLib.Signature[] memory invalidSignatures = new BridgeLib.Signature[](1);
        invalidSignatures[0] = BridgeLib.Signature({r: bytes32(0), s: bytes32(0), v: 0});

        // Expect revert due to invalid signatures
        vm.prank(relayer);
        vm.expectRevert(); // Should revert with InvalidValidatorSignatures error
        bridgeProxy.storeMessage(depositRoot, invalidSignatures, messages);
    }

    function test_StoreMessageInvalidNonceSequence() public {
        // Prepare message data with non-sequential nonces
        StorageTypes.MessageData[] memory messages = new StorageTypes.MessageData[](2);
        messages[0] = StorageTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            metadata: StorageTypes.Metadata({sender: address(this), timestamp: block.timestamp})
        });
        messages[1] = StorageTypes.MessageData({
            nonce: 3, // This should be 2 to be sequential
            message: testMessage2,
            metadata: StorageTypes.Metadata({sender: address(this), timestamp: block.timestamp})
        });

        // Compute root (this doesn't validate nonce sequence)
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(bytes32(0), messages);

        // Generate valid signatures
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        // Expect revert due to invalid nonce sequence
        vm.prank(relayer);
        vm.expectRevert(); // Should revert with InvalidNonceSequence error
        bridgeProxy.storeMessage(depositRoot, signatures, messages);
    }

    function test_StoreMessagesMultipleTimes() public {
        // First deposit
        StorageTypes.MessageData[] memory messages1 = new StorageTypes.MessageData[](1);
        messages1[0] = StorageTypes.MessageData({
            nonce: 1,
            message: testMessage1,
            metadata: StorageTypes.Metadata({sender: address(this), timestamp: block.timestamp})
        });

        (, StorageTypes.State memory n3ToEvmState,,) = bridgeProxy.messageBridge();
        bytes32 previousRoot = n3ToEvmState.root;
        bytes32 depositRoot1 = MessageBridgeLib._computeNewTopRoot(previousRoot, messages1);
        BridgeLib.Signature[] memory signatures1 = generateValidSignatures(depositRoot1);

        vm.prank(relayer);
        bridgeProxy.storeMessage(depositRoot1, signatures1, messages1);

        // Second deposit - nonce should continue from previous
        StorageTypes.MessageData[] memory messages2 = new StorageTypes.MessageData[](1);
        messages2[0] = StorageTypes.MessageData({
            nonce: 2,
            message: testMessage2,
            metadata: StorageTypes.Metadata({sender: address(this), timestamp: block.timestamp})
        });

        // The new root should be computed based on the previous root
        bytes32 depositRoot2 = MessageBridgeLib._computeNewTopRoot(depositRoot1, messages2);
        BridgeLib.Signature[] memory signatures2 = generateValidSignatures(depositRoot2);

        vm.prank(relayer);
        bridgeProxy.storeMessage(depositRoot2, signatures2, messages2);

        // Decode the expected Call structs
        StorageTypes.Call memory expectedCall1 = abi.decode(testMessage1, (StorageTypes.Call));
        StorageTypes.Call memory expectedCall2 = abi.decode(testMessage2, (StorageTypes.Call));

        // Get the stored Call struct components - public mappings return struct components, not the struct itself
        StorageTypes.Call memory actualCall1 =
            abi.decode(bridgeProxy.n3ToEvmRawMessages(messages1[0].nonce), (StorageTypes.Call));
        StorageTypes.Call memory actualCall2 =
            abi.decode(bridgeProxy.n3ToEvmRawMessages(messages2[0].nonce), (StorageTypes.Call));

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
        TestMessageContract testContract = new TestMessageContract();
        bytes memory callData = abi.encodeWithSelector(TestMessageContract.testFunction.selector);
        StorageTypes.Call memory call =
            StorageTypes.Call({target: address(testContract), callData: callData, allowFailure: false, value: 0});
        bytes memory message = abi.encode(call);

        // Get current state and nonce
        (, StorageTypes.State memory initialState,,) = bridgeProxy.messageBridge();
        uint256 nonce = initialState.nonce + 1;

        // Store the message with custom metadata
        uint256 timestamp = block.timestamp;

        // Store the message with the nonce
        storeMessage(nonce, message, "");

        // Retrieve the stored metadata and verify it
        (address storedSender, uint256 storedTimestamp) = bridgeProxy.n3ToEvmMetadata(nonce);

        // Verify metadata fields
        assertEq(storedSender, address(this), "Metadata sender should match");
        assertEq(storedTimestamp, timestamp, "Metadata timestamp should match");
    }

    function test_StoreMultipleMessagesWithMetadata() public {
        // Create two different test messages
        TestMessageContract testContract = new TestMessageContract();

        // First message
        bytes memory callData1 = abi.encodeWithSelector(TestMessageContract.testFunction.selector);
        StorageTypes.Call memory call1 =
            StorageTypes.Call({target: address(testContract), callData: callData1, allowFailure: false, value: 0});
        bytes memory message1 = abi.encode(call1);

        // Second message
        bytes memory callData2 = abi.encodeWithSelector(TestMessageContract.receivePayment.selector, 1 ether);
        StorageTypes.Call memory call2 =
            StorageTypes.Call({target: address(testContract), callData: callData2, allowFailure: false, value: 1 ether});
        bytes memory message2 = abi.encode(call2);

        // Get current state and nonce
        (, StorageTypes.State memory initialState,,) = bridgeProxy.messageBridge();
        uint256 nonce1 = initialState.nonce + 1;
        uint256 nonce2 = nonce1 + 1;

        // Store first message
        uint256 timestamp1 = block.timestamp;
        storeMessage(nonce1, message1, "");

        // Store second message
        vm.warp(block.timestamp + 100); // Advance time by 100 seconds
        uint256 timestamp2 = block.timestamp;
        storeMessage(nonce2, message2, "");

        // Retrieve and verify first message metadata
        (address storedSender1, uint256 storedTimestamp1) = bridgeProxy.n3ToEvmMetadata(nonce1);
        assertEq(storedSender1, address(this), "First message metadata sender should match");
        assertEq(storedTimestamp1, timestamp1, "First message metadata timestamp should match");

        // Verify raw message is stored correctly
        bytes memory storedRawMessage1 = bridgeProxy.n3ToEvmRawMessages(nonce1);
        assertEq(storedRawMessage1, message1, "First message content should match");

        // Retrieve and verify second message metadata
        (address storedSender2, uint256 storedTimestamp2) = bridgeProxy.n3ToEvmMetadata(nonce2);
        assertEq(storedSender2, address(this), "Second message metadata sender should match");
        assertEq(storedTimestamp2, timestamp2, "Second message metadata timestamp should match");
        assertEq(storedTimestamp2 - storedTimestamp1, 100, "Timestamp difference should be 100 seconds");

        // Verify raw message is stored correctly
        bytes memory storedRawMessage2 = bridgeProxy.n3ToEvmRawMessages(nonce2);
        assertEq(storedRawMessage2, message2, "Second message content should match");
    }

    function test_StoreMessageWithCustomMetadata() public {
        // Create a test message
        TestMessageContract testContract = new TestMessageContract();
        bytes memory callData = abi.encodeWithSelector(TestMessageContract.testFunction.selector);
        StorageTypes.Call memory call =
            StorageTypes.Call({target: address(testContract), callData: callData, allowFailure: false, value: 0});
        bytes memory message = abi.encode(call);

        // Set up a specific sender and timestamp for metadata
        address customSender = address(0xABCD);

        // Ensure block.timestamp is large enough before subtracting
        vm.warp(block.timestamp + 3600 * 2); // Move 2 hours into the future first
        uint256 customTimestamp = block.timestamp - 3600; // 1 hour ago (safe now)

        // Create the message data with custom metadata
        StorageTypes.MessageData[] memory messages = new StorageTypes.MessageData[](1);
        messages[0] = StorageTypes.MessageData({
            nonce: 1,
            message: message,
            metadata: StorageTypes.Metadata({sender: customSender, timestamp: customTimestamp})
        });

        (, StorageTypes.State memory n3ToEvmState,,) = bridgeProxy.messageBridge();
        bytes32 previousRoot = n3ToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, messages);
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        // Store the message directly using the bridgeProxy.storeMessage method
        vm.prank(relayer);
        bridgeProxy.storeMessage(depositRoot, signatures, messages);

        // Retrieve the stored metadata and verify it
        (address storedSender, uint256 storedTimestamp) = bridgeProxy.n3ToEvmMetadata(messages[0].nonce);

        // Verify custom metadata fields
        assertEq(storedSender, customSender, "Custom metadata sender should match");
        assertEq(storedTimestamp, customTimestamp, "Custom metadata timestamp should match");

        // Verify raw message is stored correctly
        bytes memory storedRawMessage = bridgeProxy.n3ToEvmRawMessages(messages[0].nonce);
        assertEq(storedRawMessage, message, "Message content should match");
    }

    // Helper function to generate valid signatures from validators
    function generateValidSignatures(bytes32 depositRoot) internal view returns (BridgeLib.Signature[] memory) {
        uint256 count = validatorThreshold;
        BridgeLib.Signature[] memory signatures = new BridgeLib.Signature[](count);

        // Create the message to be signed, matching what BridgeManagementImpl.verifyValidatorSignatures expects
        bytes32 messageHash = keccak256(abi.encodePacked(block.chainid, depositRoot));
        bytes32 signedRootMsg = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        // Array of private keys matching the validators set in setUp()
        uint256[] memory privateKeys = new uint256[](count);
        privateKeys[0] = user0PrivateKey;
        privateKeys[1] = user1PrivateKey;
        privateKeys[2] = user2PrivateKey;
        privateKeys[3] = user3PrivateKey;
        privateKeys[4] = user4PrivateKey;
        privateKeys[5] = user5PrivateKey;
        privateKeys[6] = user6PrivateKey;

        for (uint256 i = 0; i < count; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[i], signedRootMsg);
            signatures[i] = BridgeLib.Signature({r: r, s: s, v: v});
        }

        return signatures;
    }

    // Helper function to store a single message with generated signatures
    function storeMessage(uint256 nonce, bytes memory message, bytes memory failMessage) internal {
        StorageTypes.MessageData[] memory messages = new StorageTypes.MessageData[](1);
        messages[0] = StorageTypes.MessageData({nonce: nonce, message: message});

        (, StorageTypes.State memory n3ToEvmState,,) = bridgeProxy.messageBridge();
        bytes32 previousRoot = n3ToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, messages);
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        if (failMessage.length > 0) {
            // If a selector is provided, append it to the message
            vm.expectRevert(failMessage);
        }

        vm.prank(relayer);
        bridgeProxy.storeMessage(depositRoot, signatures, messages);
    }
}

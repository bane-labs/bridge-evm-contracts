// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {MessageBridgeTestHelper} from "./MessageBridgeTestHelper.sol";
import {AMBTypes} from "../contracts/library/AMBTypes.sol";
import {AMBStorage} from "../contracts/library/AMBStorage.sol";
import {BridgeLib} from "../contracts/library/BridgeLib.sol";
import {MessageBridgeLib} from "../contracts/library/MessageBridgeLib.sol";
import {StorageTypes} from "../contracts/library/StorageTypes.sol";
import {ExecutionManager} from "../contracts/messageBridge/ExecutionManager.sol";
import {MessageBridge} from "../contracts/messageBridge/MessageBridge.sol";
import {IMessageBridge} from "../contracts/messageBridge/interfaces/IMessageBridge.sol";
import {ReentrancyAttacker} from "../contracts/tests/ReentrancyAttacker.sol";
import {SigUtils} from "../contracts/tests/SigUtils.sol";
import {TestBridgeManagement} from "../contracts/tests/TestBridgeManagement.sol";
import {TestContract} from "../contracts/tests/TestContract.sol";
import {TestMessageBridge} from "../contracts/tests/TestMessageBridge.sol";
import {TestPayableContract} from "../contracts/tests/TestPayableContract.sol";
import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {Options} from "../lib/openzeppelin-foundry-upgrades/src/Options.sol";
import {Upgrades} from "../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import {console2} from "../lib/openzeppelin-foundry-upgrades/lib/forge-std/src/console2.sol";

contract MessageBridgeSyncSending is MessageBridgeTestHelper {
    function test_StoreAndExecuteMessageWithTryoutFunctionWithArgs_SyncTest() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        assertEq(testContract.counter(), 0, "Counter should be initialized to 0");

        // Arguments for the tryoutFunctionWithArgs function
        uint256 arg1 = 100;
        uint256 arg2 = 200;

        // Encode the Call struct into a message
        bytes memory message;

        {
            AMBTypes.Call memory call = AMBTypes.Call({
                target: address(testContract),
                allowFailure: false,
                value: 0,
                callData: abi.encodeWithSelector(TestContract.tryoutFunctionWithArgs.selector, arg1, arg2)
            });

            message = abi.encode(call);

            // Log the description and parameters of the method
            console2.logString("--------------------------------------------------");
            console2.logString("Executing tryoutFunctionWithArgs with parameters:");
            console2.logString("function name: tryoutFunctionWithArgs");
            console2.logUint(arg1);
            console2.logUint(arg2);
            console2.logString("--------------------------------------------------");

            console2.logString("    struct Call {");
            console2.logString("        address target; // TestContract");
            console2.logString("        bool allowFailure; ");
            console2.logString("        uint256 value;");
            console2.logString(
                "        bytes callData; // TestContract.tryoutFunctionWithArgs(uint256 arg1, uint256 arg2)"
            );
            console2.logString("    }");
            console2.logString("--------------------------------------------------");

            console2.logString("target:");
            console2.logAddress(address(testContract));
            console2.logString("allowFailure:");
            console2.logBool(call.allowFailure);
            console2.logString("value:");
            console2.logUint(call.value);
            console2.logString("callData:");
            console2.logBytes(abi.encodeWithSelector(TestContract.tryoutFunctionWithArgs.selector, arg1, arg2));
            console2.logString("--------------------------------------------------");
            console2.logString("Encoded call message:");
            console2.logBytes(message);
            console2.logString("--------------------------------------------------");
            console2.logString("\n\n\n\n\n\n");
        }

        assertEq(
            message,
            hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000001d1499e622d69689cdf9004d05ec547d650ff2110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000044cadc7a78000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000c800000000000000000000000000000000000000000000000000000000"
        );

        // Output of the event of sending the above raw message
        // // metadata+msghash+root
        // 400421002106a1075d52980128146b496d02917756d2f4f6e16e2b061875706caeef2001
        // = {0,1753728485281,6b496d02917756d2f4f6e16e2b061875706caeef,true}
        // f6250a416b970cec73cf1a37502a203179dadc9ea7770cb513fd7911248a6576
        // 61767a02fb2c69e52dbd50f7034804a28551005199c6dacef6c05e0dc5aa68d6

        // Create metadata for the message
        AMBTypes.MetadataExecutable memory metadata = AMBTypes.MetadataExecutable({
            msgType: AMBTypes.MessageType.EXECUTABLE,
            timestamp: 1753731472616, // N3 timestamp in milliseconds
            sender: address(0x639Ab3eEC9bFc00d00E0e608ec2DF87C7D98D79a),
            storeResult: true
        });

        bytes memory packedMessage = abi.encodePacked(
            uint256(1), metadata.msgType, metadata.timestamp, metadata.sender, metadata.storeResult, message
        );

        console2.logString("Packed message:");
        console2.logBytes(packedMessage);
        // The following expected concatenated bytes were the outcome in the event of sending the above raw message on the N3 contract
        assertEq(
            packedMessage,
            hex"00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000198528a9ce8639ab3eec9bfc00d00e0e608ec2df87c7d98d79a0100000000000000000000000000000000000000000000000000000000000000200000000000000000000000001d1499e622d69689cdf9004d05ec547d650ff2110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000044cadc7a78000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000c800000000000000000000000000000000000000000000000000000000"
        );

        bytes32 actualMsgHash = MessageBridgeLib._hashMessageBridgeOp(1, abi.encode(metadata), message);
        console2.logBytes32(actualMsgHash);
        // The following expected hash was the outcome in the event of sending the above message on the N3 contract
        assertEq(
            actualMsgHash,
            hex"9aa1ed575b335ac37130e30a21d7f8f6746e4f5036113ff516b91841b468559c",
            "Message hash should match expected value"
        );

        AMBStorage.MessageBridgeState memory bridgeState = messageBridgeProxy.getMessageBridgeState();
        bytes32 previousRoot = bridgeState.n3ToEvmState.root;
        assertEq(previousRoot, hex"0000000000000000000000000000000000000000000000000000000000000000"); // Initial root should be zero

        bytes32 newEvmRoot = BridgeLib._computeNewRoot(previousRoot, actualMsgHash);
        assertEq(
            newEvmRoot,
            hex"56f217582879e59a39195e5b45efb35c1fa0cfc6d03569b2f6b1f53777508c56",
            "New EVM root should match expected value"
        );

        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({nonce: 1, message: message, encodedMetadata: abi.encode(metadata)});

        BridgeLib.Signature[] memory signatures = generateValidSignatures(newEvmRoot);

        vm.prank(relayer);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.MessageDepositRootUpdate(1, newEvmRoot);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.MessageDeposit(1, message);
        messageBridgeProxy.storeMessage(newEvmRoot, signatures, messages);

        // counter += 1;
        // emit TestEvent(counter, msg.sender);
        // return arg1 + arg2; // should return 300 = arg1 + arg2

        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.MessageExecuted(1, AMBTypes.Result({success: true, returnData: abi.encode(300)}));
        // vm.expectEmit(true, true, true, true, address(testContract));
        // emit TestContract.TestEvent(1, address(executionManager));
        messageBridgeProxy.executeMessage(1);

        assertEq(testContract.counter(), 1, "Counter should be incremented to 1 after execution");
    }
}

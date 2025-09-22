// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBStorage} from "../contracts/messageBridge/AMBStorage.sol";
import {AMBTypes} from "../contracts/library/AMBTypes.sol";
import {BridgeLib} from "../contracts/library/BridgeLib.sol";
import {MessageBridgeLib} from "../contracts/library/MessageBridgeLib.sol";
import {IMessageBridge} from "../contracts/messageBridge/interfaces/IMessageBridge.sol";
import {TestContract} from "../contracts/tests/TestContract.sol";
import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {console2} from "../lib/openzeppelin-foundry-upgrades/lib/forge-std/src/console2.sol";
import {MessageBridgeTestHelper} from "./MessageBridgeTestHelper.sol";

contract MessageBridgeSyncStoring is MessageBridgeTestHelper {
    function test_SyncTest_StoreMessageAndThenExecuteSuccessfully() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        assertEq(testContract.counter(), 0, "Counter should be initialized to 0");

        // Arguments for the tryoutFunctionWithArgs function
        uint256 arg1 = 100;
        uint256 arg2 = 200;

        bytes memory message = _prepareMessage(testContract, arg1, arg2);

        // Create metadata and compute hashes
        (AMBTypes.MetadataExecutable memory metadata, bytes32 newEvmRoot) = _createMetadataAndComputeHashes(message);

        // Store the message
        _storeMessage(metadata, message, newEvmRoot);

        // Execute the message and verify results
        _executeMessageAndVerify(testContract);
    }

    function _prepareMessage(
        TestContract testContract,
        uint256 arg1,
        uint256 arg2
    )
        private
        pure
        returns (bytes memory message)
    {
        // Encode the Call struct into a message
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
        console2.logString("        bytes callData; // TestContract.tryoutFunctionWithArgs(uint256 arg1, uint256 arg2)");
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
        assertEq(
            message,
            hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000001d1499e622d69689cdf9004d05ec547d650ff2110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000044cadc7a78000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000c800000000000000000000000000000000000000000000000000000000"
        );

        // expected msg hash:
        // with nonce: 1
        // with message type: 0 // EXECUTABLE
        // with timestamp: 1753776888950
        // with sender: 0x639Ab3eEC9bFc00d00E0e608ec2DF87C7D98D79a
        // with store result: true
        // with raw message:
        // 00000000000000000000000000000000000000000000000000000000000000200000000000000000000000001d1499e622d69689cdf9004d05ec547d650ff2110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000044cadc7a78000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000c800000000000000000000000000000000000000000000000000000000
    }

    function _createMetadataAndComputeHashes(bytes memory message)
        private
        view
        returns (AMBTypes.MetadataExecutable memory metadata, bytes32 newEvmRoot)
    {
        // Create metadata for the message
        metadata = AMBTypes.MetadataExecutable({
            msgType: AMBTypes.MessageType.EXECUTABLE,
            timestamp: 1753776888950, // N3 timestamp in milliseconds
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
            hex"00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000198553f9c76639ab3eec9bfc00d00e0e608ec2df87c7d98d79a0100000000000000000000000000000000000000000000000000000000000000200000000000000000000000001d1499e622d69689cdf9004d05ec547d650ff2110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000044cadc7a78000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000c800000000000000000000000000000000000000000000000000000000"
        );

        bytes32 actualMsgHash = MessageBridgeLib._hashMessageBridgeOp(1, abi.encode(metadata), message);
        console2.logBytes32(actualMsgHash);
        // The following expected hash was the outcome in the event of sending the above message on the N3 contract
        assertEq(
            actualMsgHash,
            hex"c5e8122e5466b9c10e150d08df380a10771467d5f6e21c5234a167f690b8934f",
            "Message hash should match expected value"
        );

        AMBStorage.MessageBridgeState memory bridgeState = messageBridgeProxy.messageBridgeState();
        bytes32 previousRoot = bridgeState.evmState.root;
        assertEq(previousRoot, hex"0000000000000000000000000000000000000000000000000000000000000000"); // Initial root should be zero

        newEvmRoot = BridgeLib._computeNewRoot(previousRoot, actualMsgHash);
        assertEq(
            newEvmRoot,
            hex"3facb48372d8e7249e3e937f17dcc44f7f1a2978e1652aaa70291789ce7c6b46",
            "New EVM root should match expected value"
        );
    }

    function _storeMessage(
        AMBTypes.MetadataExecutable memory metadata,
        bytes memory message,
        bytes32 newEvmRoot
    )
        private
    {
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({nonce: 1, message: message, encodedMetadata: abi.encode(metadata)});

        BridgeLib.Signature[] memory signatures = generateValidSignatures(newEvmRoot);

        vm.prank(relayer);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.EvmRootUpdate(1, newEvmRoot);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.MessageDeposit(1, message);
        messageBridgeProxy.storeMessages(newEvmRoot, signatures, messages);
    }

    function _executeMessageAndVerify(TestContract testContract) private {
        vm.expectEmit(true, true, true, true, address(testContract));
        emit TestContract.TestEvent(1, address(executionManager));
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.MessageExecuted(1, AMBTypes.Result({success: true, returnData: abi.encode(300)}));
        messageBridgeProxy.executeMessage(1);

        assertEq(testContract.counter(), 1, "Counter should be incremented to 1 after execution");
    }

    function test_SyncTest_StoreOnlyMessage() public {
        storeDummyMessageForStoreOnlySyncTest(); // make sure the nonce is at 1 when we start this test
        AMBStorage.MessageBridgeState memory initialBridgeState = messageBridgeProxy.messageBridgeState();
        bytes32 initialEvmRoot = initialBridgeState.evmState.root;

        bytes memory message =
            hex"54686572652773206e6f776865726520492063616e277420676f2e2054686572652773206e6f7768657265204920776f6e27742066696e6420796f752e";

        // expected msg hash: 8537f0ee02066de1943c2205cd4621209dd1ec1a61ae887c5d394d130b63709a
        // with nonce: 2
        // with message type: 1 // STORE_ONLY
        // with timestamp: 1753777092836
        // with sender: 0x639Ab3eEC9bFc00d00E0e608ec2DF87C7D98D79a
        // with raw message:
        // 54686572652773206e6f776865726520492063616e277420676f2e2054686572652773206e6f7768657265204920776f6e27742066696e6420796f752e

        // Create metadata for the message
        AMBTypes.MetadataStoreOnly memory metadata = AMBTypes.MetadataStoreOnly({
            msgType: AMBTypes.MessageType.STORE_ONLY,
            timestamp: 1753777092836, // N3 timestamp in milliseconds
            sender: address(0x639Ab3eEC9bFc00d00E0e608ec2DF87C7D98D79a)
        });

        bytes memory packedMessage =
            abi.encodePacked(uint256(2), metadata.msgType, metadata.timestamp, metadata.sender, message);

        console2.logString("Packed message:");
        console2.logBytes(packedMessage);
        // The following expected concatenated bytes were the outcome in the event of sending the above raw message on the N3 contract
        assertEq(
            packedMessage,
            hex"000000000000000000000000000000000000000000000000000000000000000201000000000000000000000000000000000000000000000000000001985542b8e4639ab3eec9bfc00d00e0e608ec2df87c7d98d79a54686572652773206e6f776865726520492063616e277420676f2e2054686572652773206e6f7768657265204920776f6e27742066696e6420796f752e"
        );

        bytes32 actualMsgHash = MessageBridgeLib._hashMessageBridgeOp(2, abi.encode(metadata), message);
        console2.logBytes32(actualMsgHash);
        // The following expected hash was the outcome in the event of sending the above message on the N3 contract
        assertEq(
            actualMsgHash,
            hex"8537f0ee02066de1943c2205cd4621209dd1ec1a61ae887c5d394d130b63709a",
            "Message hash should match expected value"
        );

        // What the initial root should be based on the presetup of the test
        assertEq(initialEvmRoot, hex"0d3e5e507d5bbe00832f282ca33df9eadabbd5763ec421f3c162cb56d6717abb");

        bytes32 newEvmRoot = BridgeLib._computeNewRoot(initialEvmRoot, actualMsgHash);
        assertEq(
            newEvmRoot,
            hex"fb2685cee11e114869c8a7f8b5ccfd08c9c669bb8db88a0eba51940307d1d7b4",
            "New EVM root should match expected value"
        );

        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({nonce: 2, message: message, encodedMetadata: abi.encode(metadata)});

        BridgeLib.Signature[] memory signatures = generateValidSignatures(newEvmRoot);

        vm.prank(relayer);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.EvmRootUpdate(2, newEvmRoot);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.MessageDeposit(2, message);
        messageBridgeProxy.storeMessages(newEvmRoot, signatures, messages);

        vm.expectRevert(
            abi.encodeWithSelector(MessageBridgeLib.UnsupportedMessageType.selector, AMBTypes.MessageType.STORE_ONLY)
        );
        messageBridgeProxy.executeMessage(2);
    }

    function test_SyncTest_ResultMessage() public {
        // storeDummyMessageForStoreOnlySyncTest(); // make sure the nonce is at 1 when we start this test
        AMBStorage.MessageBridgeState memory initialBridgeState = messageBridgeProxy.messageBridgeState();
        bytes32 initialEvmRoot = initialBridgeState.evmState.root;

        bytes memory message = hex"210340420f";

        // expected msg hash: 0x92c4ccaaedaa74d8f0f40138ec1d309dd853e378b70695981070e7a16e732de3
        // with nonce: 1
        // with message type: 2 // RESULT
        // with timestamp: 1753802922973
        // with sender: 4e2381e7d7cbb4a23c7776be28276ffc107ae28c
        // with related message nonce: 1
        // with raw message: 210340420f

        // Create metadata for the message
        AMBTypes.MetadataResult memory metadata = AMBTypes.MetadataResult({
            msgType: AMBTypes.MessageType.RESULT,
            timestamp: 1753802922973, // N3 timestamp in milliseconds
            sender: address(0x4E2381E7d7CBB4A23C7776Be28276FFc107aE28c),
            relatedMessageNonce: 1
        });

        bytes memory packedMessage = abi.encodePacked(
            uint256(1), metadata.msgType, metadata.timestamp, metadata.sender, metadata.relatedMessageNonce, message
        );

        console2.logString("Packed message:");
        console2.logBytes(packedMessage);
        // The following expected concatenated bytes were the outcome in the event of sending the above raw message on the N3 contract
        assertEq(
            packedMessage,
            hex"0000000000000000000000000000000000000000000000000000000000000001020000000000000000000000000000000000000000000000000000019856ccdbdd4e2381e7d7cbb4a23c7776be28276ffc107ae28c0000000000000000000000000000000000000000000000000000000000000001210340420f"
        );

        bytes32 actualMsgHash = MessageBridgeLib._hashMessageBridgeOp(1, abi.encode(metadata), message);
        console2.logBytes32(actualMsgHash);
        // The following expected hash was the outcome in the event of sending the above message on the N3 contract
        assertEq(
            actualMsgHash,
            hex"92c4ccaaedaa74d8f0f40138ec1d309dd853e378b70695981070e7a16e732de3",
            "Message hash should match expected value"
        );

        // What the initial root should be based on the presetup of the test
        assertEq(initialEvmRoot, hex"0000000000000000000000000000000000000000000000000000000000000000");

        bytes32 newEvmRoot = BridgeLib._computeNewRoot(initialEvmRoot, actualMsgHash);
        assertEq(
            newEvmRoot,
            hex"f35faf897372612929949a29991880c3f7e77281410c942270f0017385c37b16",
            "New EVM root should match expected value"
        );

        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({nonce: 1, message: message, encodedMetadata: abi.encode(metadata)});

        BridgeLib.Signature[] memory signatures = generateValidSignatures(newEvmRoot);

        vm.prank(relayer);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.EvmRootUpdate(1, newEvmRoot);
        vm.expectEmit(true, true, true, true, address(messageBridgeProxy));
        emit IMessageBridge.MessageDeposit(1, message);
        messageBridgeProxy.storeMessages(newEvmRoot, signatures, messages);

        vm.expectRevert(
            abi.encodeWithSelector(MessageBridgeLib.UnsupportedMessageType.selector, AMBTypes.MessageType.RESULT)
        );
        messageBridgeProxy.executeMessage(1);
    }

    function storeDummyMessageForStoreOnlySyncTest() private {
        // Create a dummy message
        bytes memory dummyMessage =
            abi.encode(AMBTypes.Call({allowFailure: false, target: address(0), value: 0, callData: ""}));

        // Store the dummy message with the specified nonce
        storeMessage(1, dummyMessage, "");
    }
}

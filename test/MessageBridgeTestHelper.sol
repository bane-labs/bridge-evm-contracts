// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AMBTypes} from "../contracts/library/AMBTypes.sol";
import {BridgeLib} from "../contracts/library/BridgeLib.sol";
import {MessageBridgeLib} from "../contracts/library/MessageBridgeLib.sol";
import {StorageTypes} from "../contracts/library/StorageTypes.sol";
import {ExecutionManager} from "../contracts/messageBridge/ExecutionManager.sol";
import {MessageBridge} from "../contracts/messageBridge/MessageBridge.sol";
import {IMessageBridge} from "../contracts/messageBridge/interfaces/IMessageBridge.sol";
import {ReentrancyAttacker} from "../contracts/tests/ReentrancyAttacker.sol";
import {SigUtils} from "../contracts/tests/SigUtils.sol";
import {TestBridgeManagement} from "../contracts/tests/TestBridgeManagement.sol";
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

abstract contract MessageBridgeTestHelper is Test, SigUtils {
    TestMessageBridge messageBridgeProxy;
    address messageBridgeProxyAddress;

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

    ExecutionManager public executionManager;

    // Message Bridge Config
    uint256 messageFee = 0.01 ether;
    uint256 maxMessageSize = 1024;
    uint256 maxNrMessages = 10;
    uint256 executionWindowSeconds = 60;

    // Test message data
    bytes testMessage1 =
        abi.encode(AMBTypes.Call({allowFailure: false, target: address(0x1234), value: 0, callData: hex"abcd"}));
    bytes testMessage2 =
        abi.encode(AMBTypes.Call({allowFailure: true, target: address(0x5678), value: 0, callData: hex"ef01"}));

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
        // Validate initialization to version 3
        assertEq(managementProxy.getCurrentInitializedVersion(), 3);

        // Deploy the MessageBridge implementation
        messageBridgeProxyAddress = Upgrades.deployUUPSProxy(
            "TestMessageBridge.sol",
            abi.encodeCall(
                TestMessageBridge.initialize,
                (managementProxyAddress, messageFee, maxMessageSize, maxNrMessages, executionWindowSeconds)
            ),
            opts
        );
        messageBridgeProxy = TestMessageBridge(payable(messageBridgeProxyAddress));

        assertTrue(messageBridgeProxy.messageBridgeIsSet(), "Message bridge should be set");

        // Deploy and set up the Message Executor
        executionManager = new ExecutionManager(messageBridgeProxyAddress);

        // Set the message executor in the bridge
        vm.prank(governor);
        messageBridgeProxy.setMessageExecutor(address(executionManager));

        // Unpause the message bridge
        vm.prank(governor);
        messageBridgeProxy.unpauseMessageBridge();
    }

    function _getAMBStorage() private pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("AMB.storage")) - 1)) & ~bytes32(uint256(0xff));
    }

    function isSendingPaused() internal view returns (bool) {
        bytes32 slotValue = vm.load(messageBridgeProxyAddress, _getAMBStorage());
        // Extract the boolean (byte at offset 20)
        // Shift right by 20 bytes (160 bits) to get the boolean at the start
        // Then mask with 0xff to isolate just that byte
        // Then check if it's non-zero (Solidity booleans are 1 for true, 0 for false)
        uint8 sendingPausedBoolByte = uint8(uint256(slotValue) >> 160) & 0xFF;
        return sendingPausedBoolByte > 0;
    }

    function isExecutingPaused() internal view returns (bool) {
        bytes32 slotValue = vm.load(messageBridgeProxyAddress, _getAMBStorage());
        // Extract the boolean (byte at offset 21)
        // Shift right by 21 bytes (168 bits) to get the boolean at the start
        // Then mask with 0xff to isolate just that byte
        // Then check if it's non-zero (Solidity booleans are 1 for true, 0 for false)
        uint8 executingPausedBoolByte = uint8(uint256(slotValue) >> 168) & 0xFF;
        return executingPausedBoolByte > 0;
    }

    // Helper function to store a single message with generated signatures
    function storeMessage(uint256 nonce, bytes memory message, bytes memory failMessage) internal {
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({
            nonce: nonce,
            message: message,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    sender: address(this),
                    timestamp: block.timestamp,
                    storeResult: false
                })
            )
        });

        StorageTypes.State memory n3ToEvmState = messageBridgeProxy.getMessageBridgeState().n3ToEvmState;
        bytes32 previousRoot = n3ToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, messages);
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        if (failMessage.length > 0) {
            // If a selector is provided, append it to the message
            vm.expectRevert(failMessage);
        }

        vm.prank(relayer);
        messageBridgeProxy.storeMessage(depositRoot, signatures, messages);
    }

    // Helper function to store a message with custom storeResult setting
    function storeMessageWithStoreResult(uint256 nonce, bytes memory message, bool storeResult) internal {
        AMBTypes.MessageData[] memory messages = new AMBTypes.MessageData[](1);
        messages[0] = AMBTypes.MessageData({
            nonce: nonce,
            message: message,
            encodedMetadata: abi.encode(
                AMBTypes.MetadataExecutable({
                    msgType: AMBTypes.MessageType.EXECUTABLE,
                    sender: address(this),
                    timestamp: block.timestamp,
                    storeResult: storeResult
                })
            )
        });

        StorageTypes.State memory n3ToEvmState = messageBridgeProxy.getMessageBridgeState().n3ToEvmState;
        bytes32 previousRoot = n3ToEvmState.root;
        bytes32 depositRoot = MessageBridgeLib._computeNewTopRoot(previousRoot, messages);
        BridgeLib.Signature[] memory signatures = generateValidSignatures(depositRoot);

        vm.prank(relayer);
        messageBridgeProxy.storeMessage(depositRoot, signatures, messages);
    }

    function storeDummyMessage(uint256 nonce) internal {
        // Create a dummy message
        bytes memory dummyMessage =
            abi.encode(AMBTypes.Call({allowFailure: false, target: address(0), value: 0, callData: ""}));

        // Store the dummy message with the specified nonce
        storeMessage(nonce, dummyMessage, "");
    }

    // Helper function to decode executable metadata from stored message
    function getExecutableMetadata(uint256 nonce) internal view returns (AMBTypes.MetadataExecutable memory) {
        bytes memory encodedMetadata = messageBridgeProxy.n3ToEvmMessages(nonce).encodedMetadata;
        AMBTypes.MessageType msgType = MessageBridgeLib._readMessageType(encodedMetadata);
        if (msgType == AMBTypes.MessageType.EXECUTABLE) {
            return abi.decode(encodedMetadata, (AMBTypes.MetadataExecutable));
        } else {
            revert("Unexpected message type");
        }
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

}

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
import {TestMessageContract} from "../contracts/tests/TestMessageContract.sol";
import {TestPayableContract} from "../contracts/tests/TestPayableContract.sol";
import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {Options} from "../lib/openzeppelin-foundry-upgrades/src/Options.sol";
import {Upgrades} from "../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";

contract MessageBridgeSyncSending is Test, SigUtils {
    TestMessageContract messageBridgeProxy;
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
    bytes testMessage1 = abi.encode(
        AMBTypes.Call({
            allowFailure: false,
            requiresResponse: false,
            target: address(0x1234),
            value: 0,
            callData: hex"abcd"
        })
    );
    bytes testMessage2 = abi.encode(
        AMBTypes.Call({
            allowFailure: true,
            requiresResponse: false,
            target: address(0x5678),
            value: 0,
            callData: hex"ef01"
        })
    );

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
            "TestMessageContract.sol",
            abi.encodeCall(
                MessageBridge.initialize,
                (managementProxyAddress, messageFee, maxMessageSize, maxNrMessages, executionWindowSeconds)
            ),
            opts
        );
        messageBridgeProxy = TestMessageContract(payable(messageBridgeProxyAddress));

        // Deploy and set up the Message Executor
        executionManager = new ExecutionManager(messageBridgeProxyAddress);

        // Set the message executor in the bridge
        vm.prank(governor);
        messageBridgeProxy.setMessageExecutor(address(executionManager));

        // Unpause the message bridge
        vm.prank(governor);
        messageBridgeProxy.unpauseMessageBridge();
    }

    function test_hashMessageSendOp_executable() public view {
        uint256 nonce = 1;
        uint256 timestamp = 1753000000;
        address sender = address(0x69eCcA587293047bE4C59159BF8BC399985C160D);
        
        bytes memory msgBytes = hex"400428141418e358c565207768eae8d237241e85d3e9f1cb280573746f72652101024002210101210440a87c68";

        AMBTypes.SendMetadataExecutable memory metadata = AMBTypes.SendMetadataExecutable({
            msgType: AMBTypes.SendMessageType.EXECUTABLE,
            timestamp: timestamp,
            sender: sender,
            storeResult: true
        });
        bytes32 hashedBridgeOp = messageBridgeProxy.hashSendMessage(nonce, abi.encode(metadata), msgBytes);
        bytes memory concatenated = abi.encodePacked(nonce, metadata.msgType, metadata.timestamp, metadata.sender, metadata.storeResult, msgBytes);
        assertEq(
            concatenated,
            hex"00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000687ca84069ecca587293047be4c59159bf8bc399985c160d01400428141418e358c565207768eae8d237241e85d3e9f1cb280573746f72652101024002210101210440a87c68"
        );
        bytes32 expected = keccak256(concatenated);
        assertEq(hashedBridgeOp, expected);
        assertEq(hashedBridgeOp, hex"2a9d36cc38d44ab810d0d484bb21f483d4ee4d676f1773859e8043e3a1d3601d");
    }

    function test_hashMessageSendOp_storeOnly() public view {
        uint256 nonce = 2;
        uint256 timestamp = 1753100005;
        address sender = address(0x82d53419cdb80A84A1A9C699C6cc333236169B98);
        
        bytes memory msgBytes = hex"5468657265e2809973206e6f776865726520492063616ee280997420676f2e205468657265e2809973206e6f7768657265204920776f6ee28099742066696e6420796f752e";

        AMBTypes.SendMetadataStoreOnly memory metadata = AMBTypes.SendMetadataStoreOnly({
            msgType: AMBTypes.SendMessageType.STORE_ONLY,
            timestamp: timestamp,
            sender: sender
        });
        bytes32 hashedBridgeOp = messageBridgeProxy.hashSendMessage(nonce, abi.encode(metadata), msgBytes);
        bytes memory concatenated = abi.encodePacked(nonce, metadata.msgType, metadata.timestamp, metadata.sender, msgBytes);
        assertEq(
            concatenated,
            hex"00000000000000000000000000000000000000000000000000000000000000020100000000000000000000000000000000000000000000000000000000687e2ee582d53419cdb80a84a1a9c699c6cc333236169b985468657265e2809973206e6f776865726520492063616ee280997420676f2e205468657265e2809973206e6f7768657265204920776f6ee28099742066696e6420796f752e"
        );
        bytes32 expected = keccak256(concatenated);
        assertEq(hashedBridgeOp, expected);
        assertEq(hashedBridgeOp, hex"6616d6d15190a04d878aed300e194a02a6b4e94eeb2084f8a5c4b73d95e92dbb");
    }

    function test_hashMessageSendOp_result() public view {
        uint256 nonce = 7592037;
        uint256 timestamp = 1753000097;
        address sender = address(0xfaDd389577eae0Af6E59f8476F9d808f120407C2);
        
        bytes memory msgBytes = hex"03e8";

        AMBTypes.SendMetadataResult memory metadata = AMBTypes.SendMetadataResult({
            msgType: AMBTypes.SendMessageType.RESULT,
            timestamp: timestamp,
            sender: sender,
            relatedMessageNonce: 1
        });
        bytes32 hashedBridgeOp = messageBridgeProxy.hashSendMessage(nonce, abi.encode(metadata), msgBytes);
        bytes memory concatenated = abi.encodePacked(nonce, metadata.msgType, metadata.timestamp, metadata.sender, metadata.relatedMessageNonce, msgBytes);
        assertEq(
            concatenated,
            hex"000000000000000000000000000000000000000000000000000000000073d8650200000000000000000000000000000000000000000000000000000000687ca8a1fadd389577eae0af6e59f8476f9d808f120407c2000000000000000000000000000000000000000000000000000000000000000103e8"
        );
        bytes32 expected = keccak256(concatenated);
        assertEq(hashedBridgeOp, expected);
        assertEq(hashedBridgeOp, hex"80d26468c8c67d4bfccc3d2ac6276ab98ccbdf1a43d3f0e18b91a6461d75ac22");
    }

}

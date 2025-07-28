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
import {MessageBridgeTestHelper} from "./MessageBridgeTestHelper.sol";
import {TestPayableContract} from "../contracts/tests/TestPayableContract.sol";
import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {Options} from "../lib/openzeppelin-foundry-upgrades/src/Options.sol";
import {Upgrades} from "../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";

contract MessageBridgeSyncSending is MessageBridgeTestHelper {
    function test_hashMessageSendOp_executable() public view {
        uint256 nonce = 1;
        uint256 timestamp = 1753000000;
        address sender = address(0x69eCcA587293047bE4C59159BF8BC399985C160D);

        bytes memory msgBytes =
            hex"400428141418e358c565207768eae8d237241e85d3e9f1cb280573746f72652101024002210101210440a87c68";

        AMBTypes.MetadataExecutable memory metadata = AMBTypes.MetadataExecutable({
            msgType: AMBTypes.MessageType.EXECUTABLE,
            timestamp: timestamp,
            sender: sender,
            storeResult: true
        });
        bytes32 hashedBridgeOp = messageBridgeProxy.hashSendMessage(nonce, abi.encode(metadata), msgBytes);
        bytes memory concatenated = abi.encodePacked(
            nonce, metadata.msgType, metadata.timestamp, metadata.sender, metadata.storeResult, msgBytes
        );
        assertEq(
            concatenated,
            //                                                                  ↓type                                                                                                     ↓store result
            // |                                                          nonce| |                                                      timestamp |                                sender| |                                                                            message bytes|
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

        bytes memory msgBytes =
            hex"5468657265e2809973206e6f776865726520492063616ee280997420676f2e205468657265e2809973206e6f7768657265204920776f6ee28099742066696e6420796f752e";

        AMBTypes.MetadataStoreOnly memory metadata =
            AMBTypes.MetadataStoreOnly({msgType: AMBTypes.MessageType.STORE_ONLY, timestamp: timestamp, sender: sender});
        bytes32 hashedBridgeOp = messageBridgeProxy.hashSendMessage(nonce, abi.encode(metadata), msgBytes);
        bytes memory concatenated =
            abi.encodePacked(nonce, metadata.msgType, metadata.timestamp, metadata.sender, msgBytes);
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

        AMBTypes.MetadataResult memory metadata = AMBTypes.MetadataResult({
            msgType: AMBTypes.MessageType.RESULT,
            timestamp: timestamp,
            sender: sender,
            relatedMessageNonce: 1
        });
        bytes32 hashedBridgeOp = messageBridgeProxy.hashSendMessage(nonce, abi.encode(metadata), msgBytes);
        bytes memory concatenated = abi.encodePacked(
            nonce, metadata.msgType, metadata.timestamp, metadata.sender, metadata.relatedMessageNonce, msgBytes
        );
        assertEq(
            concatenated,
            hex"000000000000000000000000000000000000000000000000000000000073d8650200000000000000000000000000000000000000000000000000000000687ca8a1fadd389577eae0af6e59f8476f9d808f120407c2000000000000000000000000000000000000000000000000000000000000000103e8"
        );
        bytes32 expected = keccak256(concatenated);
        assertEq(hashedBridgeOp, expected);
        assertEq(hashedBridgeOp, hex"80d26468c8c67d4bfccc3d2ac6276ab98ccbdf1a43d3f0e18b91a6461d75ac22");
    }
}

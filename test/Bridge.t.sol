// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BridgeStorage, StorageTypes} from "../contracts/bridge/BridgeStorage.sol";
import {ITokenBridge} from "../contracts/interfaces/ITokenBridge.sol";
import {SigUtils} from "../contracts/tests/SigUtils.sol";
import {TestBridge, BridgeImpl} from "../contracts/tests/TestBridge.sol";
import {TestBridgeManagement} from "../contracts/tests/TestBridgeManagement.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {TestContract} from "../contracts/tests/TestContract.sol";

contract BridgeImplTest is Test, SigUtils {
    TestBridge bridgeProxy;
    address bridgeProxyAddress;

    address neoXToken = address(0x6789);
    address neoN3Token = address(0x7892);
    StorageTypes.TokenConfig validConfig;

    // Managment
    TestBridgeManagement managementProxy;
    address managementProxyAddress;
    SigUtils sigUtils;
    address public owner = 0xBcd4042DE499D14e55001CcbB24a551F3b954096;
    address public funder = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public relayer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint8 public validatorThreshold = 5;
    address[] public validatorsAddresses;
    address internal governor = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    address internal securityGuard = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

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
        // The constructor only contains _disableInitializers() which is safe to bypass.
        Options memory opts;
        opts.unsafeAllow = "constructor";
        // Deploy the bridge management implementation and make sure it's initialized to the latest implementation.
        managementProxyAddress = Upgrades.deployUUPSProxy(
            "TestBridgeManagement.sol",
            abi.encodeCall(
                TestBridgeManagement.initialize,
                (owner, relayer, 7, validatorsAddresses, governor, securityGuard, funder)
            ),
            opts
        );
        managementProxy = TestBridgeManagement(payable(managementProxyAddress));
        // vm.prank(owner);
        // managementProxy.upgradeToV<version_nr>();
        // Validate that the bridge proxy has been successfully deployed and initialized to version 3.
        assertEq(managementProxy.getCurrentInitializedVersion(), 3);

        // Deploy the bridge and make sure it's initialized to the latest implementation.
        bridgeProxyAddress = Upgrades.deployUUPSProxy(
            "TestBridge.sol", abi.encodeCall(TestBridge.initialize, (managementProxyAddress)), opts
        );
        bridgeProxy = TestBridge(payable(bridgeProxyAddress));
        // vm.prank(owner);
        // bridgeProxy.upgradeToV<version_nr>();
        assertFalse(bridgeProxy.nativeBridgeIsSet());
        vm.prank(governor);
        bridgeProxy.setNativeBridge(1e17, 1e18, 1e22, 100, 18, 8);
        assertTrue(bridgeProxy.nativeBridgeIsSet());

        vm.prank(governor);
        bridgeProxy.unpauseNativeBridge();

        // Validate that the bridge proxy has been successfully deployed and initialized to version 3.
        assertEq(bridgeProxy.getCurrentInitializedVersion(), 3);

        validConfig = StorageTypes.TokenConfig({
            neoN3Token: neoN3Token,
            fee: 1,
            minAmount: 100,
            maxAmount: 1000,
            maxDeposits: 10,
            decimalScalingFactor: 18
        });
    }

    function registerTokenAndUnpause(address token, StorageTypes.TokenConfig memory config) public {
        vm.prank(governor);
        bridgeProxy.registerToken(token, config);
        vm.prank(governor);
        bridgeProxy.unpauseTokenBridge(token);
    }

    // test case: successful register token bridge, check result and event
    function testRegisterToken() public {
        // check register token successful event
        vm.expectEmit(true, true, true, true);
        emit ITokenBridge.TokenRegister(neoXToken, validConfig);

        // Mock the registration of the token
        vm.prank(governor);
        bridgeProxy.registerToken(neoXToken, validConfig);
        StorageTypes.TokenConfig memory config = bridgeProxy.getTokenConfig(neoXToken);

        // check register token successful result
        assertEq(config.neoN3Token, neoN3Token, "Neo N3 Token");
        assertEq(config.fee, 1, "Fee");
        assertEq(config.minAmount, 100, "Min Amount");
        assertEq(config.maxAmount, 1000, "Max Amount");
        assertEq(config.maxDeposits, 10, "Max Deposits");
    }

    // test case: successful register token bridge
    function test_RegisterTokenWithZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(BridgeStorage.InvalidTokenAddress.selector);
        bridgeProxy.registerToken(address(0), validConfig);
    }

    // test case: register token bridge, with an invalid amount, minAmount>maxAmount
    function test_RegisterTokenWithInvalidConfig() public {
        vm.prank(governor);
        vm.expectRevert(BridgeStorage.InvalidTokenConfig.selector);
        StorageTypes.TokenConfig memory invalidConfig = StorageTypes.TokenConfig({
            neoN3Token: neoN3Token,
            fee: 1,
            minAmount: 1000,
            maxAmount: 100,
            maxDeposits: 10,
            decimalScalingFactor: 18
        });
        bridgeProxy.registerToken(neoXToken, invalidConfig);
    }

    // test case: register token bridge, with an invalid Fee:0
    function test_RegisterTokenWithInvalidFee() public {
        vm.prank(governor);
        vm.expectRevert(BridgeStorage.InvalidTokenConfig.selector);
        StorageTypes.TokenConfig memory invalidConfig = StorageTypes.TokenConfig({
            neoN3Token: neoN3Token,
            fee: 0,
            minAmount: 1,
            maxAmount: 10000,
            maxDeposits: 10,
            decimalScalingFactor: 18
        });
        bridgeProxy.registerToken(neoXToken, invalidConfig);
    }

    // test case: register token bridge, with an invalid minAmount:0
    function test_RegisterTokenWithInvalidMinAmount() public {
        vm.prank(governor);
        vm.expectRevert(BridgeStorage.InvalidTokenConfig.selector);
        StorageTypes.TokenConfig memory invalidConfig = StorageTypes.TokenConfig({
            neoN3Token: neoN3Token,
            fee: 1,
            minAmount: 0,
            maxAmount: 100,
            maxDeposits: 10,
            decimalScalingFactor: 18
        });
        bridgeProxy.registerToken(neoXToken, invalidConfig);
    }

    // test case: register token bridge, with an invalid neoN3Token:0 address
    function test_RegisterTokenWithInvalidNeoN3TokenAddress() public {
        vm.prank(governor);
        vm.expectRevert(BridgeStorage.InvalidTokenConfig.selector);
        StorageTypes.TokenConfig memory invalidConfig = StorageTypes.TokenConfig({
            neoN3Token: address(0),
            fee: 1,
            minAmount: 100,
            maxAmount: 1000,
            maxDeposits: 10,
            decimalScalingFactor: 18
        });
        bridgeProxy.registerToken(neoXToken, invalidConfig);
    }

    // test case: register token bridge, token bridge already registered
    function test_RegisterTokenAlreadyRegistered() public {
        vm.prank(governor);
        bridgeProxy.registerToken(neoXToken, validConfig);
        vm.expectRevert(abi.encodeWithSelector(BridgeStorage.TokenBridgeAlreadyRegistered.selector, neoXToken));
        vm.prank(governor);
        bridgeProxy.registerToken(neoXToken, validConfig);
    }

    // test case: register token bridge but not governor
    function test_RegisterTokenByNonGovernor() public {
        vm.prank(address(0x456));
        vm.expectRevert("not governor");
        bridgeProxy.registerToken(neoXToken, validConfig);
    }

    // test case: successful pause token bridge, check result and event
    function testPauseTokenBridge() public {
        registerTokenAndUnpause(neoXToken, validConfig);
        bool tokenBridgePaused = bridgeProxy.getTokenbridgePaused(neoXToken);
        // Ensure the token bridge is not paused
        assertFalse(tokenBridgePaused);

        // check pause token successful event
        vm.expectEmit(true, true, true, true);
        address afterNeoN3Token = bridgeProxy.getNeoN3Token(neoXToken);
        emit ITokenBridge.TokenBridgePause(neoXToken, afterNeoN3Token);

        // Pause the token bridge
        vm.prank(securityGuard);
        bridgeProxy.pauseTokenBridge(neoXToken);

        // Verify the token bridge is paused
        bool afterTokenBridgePaused = bridgeProxy.getTokenbridgePaused(neoXToken);
        assertTrue(afterTokenBridgePaused);
    }

    // test case: pause token when token is already paused
    function test_PauseTokenBridgeWhenAlreadyPaused() public {
        registerTokenAndUnpause(neoXToken, validConfig);
        // Pause the token bridge first
        vm.prank(securityGuard);
        bridgeProxy.pauseTokenBridge(neoXToken);

        // Attempt to pause the token bridge again
        vm.prank(securityGuard);
        vm.expectRevert(abi.encodeWithSignature("TokenBridgePaused(address)", neoXToken));
        bridgeProxy.pauseTokenBridge(neoXToken);
    }

    // test case: pause token bridge when token bridge is not registered
    function test_PauseTokenBridgeWhenNotRegistered() public {
        address unregisteredToken = address(0xDEF);

        // Attempt to pause an unregistered token bridge
        vm.prank(securityGuard);
        vm.expectRevert(abi.encodeWithSignature("TokenBridgeNotRegistered(address)", unregisteredToken));
        bridgeProxy.pauseTokenBridge(unregisteredToken);
    }

    // test case: pause token bridge but not securityGuard
    function test_PauseTokenBridgeByNonSecurityGuard() public {
        // Attempt to pause the token bridge by a non-security guard
        address nonSecurityGuard = address(0x654);
        vm.prank(nonSecurityGuard);
        vm.expectRevert(BridgeStorage.NoAuthorization.selector);
        bridgeProxy.pauseTokenBridge(neoXToken);
    }

    // test case: successful unpause token bridge, check result and event
    function testUnpauseTokenBridge() public {
        registerTokenAndUnpause(neoXToken, validConfig);
        bool tokenBridgePaused = bridgeProxy.getTokenbridgePaused(neoXToken);
        // Ensure the token bridge is not paused
        assertFalse(tokenBridgePaused);

        // Pause the token bridge
        vm.prank(securityGuard);
        bridgeProxy.pauseTokenBridge(neoXToken);

        // Verify the token bridge is paused
        bool afterTokenBridgePaused = bridgeProxy.getTokenbridgePaused(neoXToken);
        assertTrue(afterTokenBridgePaused);

        // unause the token bridge, check unpause token successful event
        vm.expectEmit(true, true, true, true);
        address afterNeoN3Token = bridgeProxy.getNeoN3Token(neoXToken);
        emit ITokenBridge.TokenBridgeUnpause(neoXToken, afterNeoN3Token);

        //unause the token bridge, check unpause token successful result
        vm.prank(governor);
        bridgeProxy.unpauseTokenBridge(neoXToken);
        bool aftersTokenBridgePaused = bridgeProxy.getTokenbridgePaused(neoXToken);
        assertFalse(aftersTokenBridgePaused);
    }

    // test case: unpause token bridge when token bridge is not paused
    function test_UnpauseTokenBridgeWhenNotPaused() public {
        // Ensure the token bridge is not paused
        registerTokenAndUnpause(neoXToken, validConfig);
        bool tokenBridgePaused = bridgeProxy.getTokenbridgePaused(neoXToken);
        // Ensure the token bridge is not paused
        assertFalse(tokenBridgePaused);

        // Attempt to unpause the token bridge
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("TokenBridgeNotPaused(address)", neoXToken));
        bridgeProxy.unpauseTokenBridge(neoXToken);
    }

    // test case: unpause token bridge when token bridge is not registered
    function test_UnpauseTokenBridgeWhenNotRegistered() public {
        address unregisteredToken = address(0xDEF);
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSelector(BridgeStorage.TokenBridgeNotRegistered.selector, unregisteredToken));
        bridgeProxy.unpauseTokenBridge(unregisteredToken);
    }

    // test case: pause token bridge but not governor
    function test_UnpauseTokenBridgeByNonGovernor() public {
        vm.prank(governor);
        bridgeProxy.registerToken(neoXToken, validConfig);
        assertTrue(bridgeProxy.getTokenbridgePaused(neoXToken));

        // Attempt to unpause the token bridge by a non-governor
        address nonGovernor = address(0x222);
        vm.prank(nonGovernor);
        vm.expectRevert("not governor");
        bridgeProxy.unpauseTokenBridge(neoXToken);
    }

    function test_StoreAndExecuteMessageWithTestContract() public {
        // Deploy test contract
        TestContract testContract = new TestContract();

        assertEq(testContract.counter(), 0, "Counter should be initialized to 0");

        // Create Call struct with testFunction encoded
        bytes memory callData = abi.encodeWithSelector(TestContract.testFunction.selector);

        StorageTypes.Call memory call = StorageTypes.Call({
            target: address(testContract),
            callData: callData,
            allowFailure: false,
            value: 0
        });

        // Encode the Call struct into a message
        bytes memory message = abi.encode(call);

        // Store the message and get the nonce
        uint256 nonce = bridgeProxy.storeMessage(message);

        // Verify the nonce is the keccak256 hash of the message
        assertEq(uint(keccak256(message)), nonce, "Nonce should be the keccak256 hash of the message");

        // Expect the TestEvent to be emitted with correct parameters
        vm.expectEmit(true, true, true, true, address(testContract));
        emit TestContract.TestEvent(1, address(bridgeProxy));

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
}

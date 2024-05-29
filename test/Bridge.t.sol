// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../lib/forge-std/src/Test.sol";
import {TestBridge} from "../contracts/tests/TestBridge.sol";
import {BridgeStorage,BridgeLib,GasBridgeLib,StorageTypes,TokenBridgeLib}from "../contracts/bridge/BridgeStorage.sol";
import "../contracts/management/BridgeManagementImpl.sol";
import "../contracts/tests/SigUtils.sol";


contract BridgeImplTest is Test,SigUtils {
    // constructor(address _management) BridgeImpl(_management) {}
    TestBridge bridgeImpl;

    address neoXToken = address(0x6789);
    address neoN3Token = address(0x7892);
    StorageTypes.TokenConfig validConfig;

    // set _management
    BridgeManagementImpl bridgeManagementImpl;
    SigUtils sigUtils;
    address public owner = 0xBcd4042DE499D14e55001CcbB24a551F3b954096;
    address public user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public relayer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint8 public validatorThreshold = 5;
    uint256[] public validatorsKeys;
    address[] public validatorsAddresses;
    address internal governor = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    address internal securityGuard = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;



    function setUp() public {
        //set  _management
        sigUtils = new SigUtils();
        validatorsKeys.push(user0PrivateKey);
        validatorsAddresses.push(vm.addr(user0PrivateKey));
        validatorsKeys.push(user1PrivateKey);
        validatorsAddresses.push(vm.addr(user1PrivateKey));
        validatorsKeys.push(user2PrivateKey);
        validatorsAddresses.push(vm.addr(user2PrivateKey));
        validatorsKeys.push(user3PrivateKey);
        validatorsAddresses.push(vm.addr(user3PrivateKey));
        validatorsKeys.push(user4PrivateKey);
        validatorsAddresses.push(vm.addr(user4PrivateKey));
        validatorsKeys.push(user5PrivateKey);
        validatorsAddresses.push(vm.addr(user5PrivateKey));
        validatorsKeys.push(user6PrivateKey);
        validatorsAddresses.push(vm.addr(user6PrivateKey));
        bridgeManagementImpl = new BridgeManagementImpl(
                owner,
                relayer,
                5,
                validatorsAddresses,
                governor,
                securityGuard,
                user
            );

        bridgeImpl = new TestBridge(address(bridgeManagementImpl));
        validConfig = StorageTypes.TokenConfig({
            neoN3Token: neoN3Token,
            fee: 1,
            minAmount: 100,
            maxAmount: 1000,
            maxDeposits: 10,
            tokenType: StorageTypes.TokenType.NEO
        });
    }


    function testRegisterToken() public {
        vm.prank(governor);
        // console.log("msg.sender: %s, token: %s",msg.sender,neoXToken);
        bridgeImpl.registerToken(neoXToken, validConfig);
        StorageTypes.TokenConfig memory config =  bridgeImpl.getTokenConfig(neoXToken);
        assertEq(config.neoN3Token, neoN3Token);
        assertEq(config.fee, 1);
        assertEq(config.minAmount, 100);
        assertEq(config.maxAmount, 1000);
        assertEq(config.maxDeposits, 10);
    }



    function test_RegisterTokenWithZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(BridgeStorage.InvalidTokenAddress.selector);
        bridgeImpl.registerToken(address(0), validConfig);
    }


    function test_RegisterTokenWithInvalidAmount() public {
        vm.prank(governor);
        vm.expectRevert(BridgeStorage.InvalidAmount.selector);
        StorageTypes.TokenConfig memory invalidConfig = StorageTypes.TokenConfig({
            neoN3Token: neoN3Token,
            fee: 1,
            minAmount: 1000,
            maxAmount: 100,
            maxDeposits: 10,
            tokenType: StorageTypes.TokenType.NEO
        });
        bridgeImpl.registerToken(neoXToken, invalidConfig);
    }

    function test_RegisterTokenWithInvalidFee() public {
        vm.prank(governor);
        vm.expectRevert(BridgeStorage.InvalidTokenConfig.selector);
        StorageTypes.TokenConfig memory invalidConfig = StorageTypes.TokenConfig({
            neoN3Token: neoN3Token,
            fee: 0,
            minAmount: 1,
            maxAmount: 10000,
            maxDeposits: 10,
            tokenType: StorageTypes.TokenType.NEO
        });
        bridgeImpl.registerToken(neoXToken, invalidConfig);
    }

    function test_RegisterTokenWithInvalidMinAmount() public {
        vm.prank(governor);       
        vm.expectRevert(BridgeStorage.InvalidTokenConfig.selector);
        StorageTypes.TokenConfig memory invalidConfig = StorageTypes.TokenConfig({
            neoN3Token: neoN3Token,
            fee: 1,
            minAmount: 0,
            maxAmount: 100,
            maxDeposits: 10,
            tokenType: StorageTypes.TokenType.NEO
        });
        bridgeImpl.registerToken(neoXToken, invalidConfig);
    }

    function test_RegisterTokenWithInvalidNeoN3TokenAddress() public {
        vm.prank(governor);
        vm.expectRevert(BridgeStorage.InvalidAddress.selector);
        StorageTypes.TokenConfig memory invalidConfig = StorageTypes.TokenConfig({
            neoN3Token: address(0),
            fee: 1,
            minAmount: 100,
            maxAmount: 1000,
            maxDeposits: 10,
            tokenType: StorageTypes.TokenType.NEO
        });
        bridgeImpl.registerToken(neoXToken, invalidConfig);
    }

    function test_RegisterTokenAlreadyRegistered() public {
        vm.prank(governor);
        bridgeImpl.registerToken(neoXToken, validConfig);
        vm.expectRevert(abi.encodeWithSelector(BridgeStorage.TokenBridgeAlreadyRegistered.selector,neoXToken));
        vm.prank(governor);
        bridgeImpl.registerToken(neoXToken, validConfig); // Should fail
    }

    function test_RegisterTokenByNonGovernorr() public{
        vm.prank(address(0x456));
        vm.expectRevert("not governor");
        bridgeImpl.registerToken(neoXToken, validConfig);
    }

    function testUnregisterToken() public {
        // Mock the registration of the token
        vm.prank(governor);
        bridgeImpl.registerToken(neoXToken, validConfig);

        // Pause the token bridge
        vm.prank(securityGuard);
        bridgeImpl.pauseTokenBridge(neoXToken);

        // Verify the token bridge is paused
        StorageTypes.TokenBridge memory tokenBridgeBefore = bridgeImpl.getTokenbridge(neoXToken);
        assertTrue(tokenBridgeBefore.paused);

        // Unregister the token
        // vm.expectEmit(true, true, true, true);
        // emit bridgeImpl.TokenUnregister(neoXToken,validConfig);
        vm.prank(governor);
        bridgeImpl.unregisterToken(neoXToken);

        // // Verify that the token bridge is unregistered
        address afterneoXToken = bridgeImpl.getNeoN3Token(neoXToken);
        assertEq(afterneoXToken, address(0));
    }
    

    function test_UnregisterTokenWhenNotPaused() public {
        vm.prank(governor);
        bridgeImpl.registerToken(neoXToken, validConfig);

        // Attempt to unregister the token without pausing
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("TokenBridgeUnpaused(address)", neoXToken));
        bridgeImpl.unregisterToken(neoXToken);
    }

    function test_UnregisterTokenByNonGovernor() public {
        vm.prank(governor);
        bridgeImpl.registerToken(neoXToken, validConfig);
        // Pause the token bridge
        vm.prank(securityGuard);
        bridgeImpl.pauseTokenBridge(neoXToken);

        // Attempt to unregister the token by non-governor
        vm.prank(address(0x456));
        vm.expectRevert("not governor");
        bridgeImpl.unregisterToken(neoXToken);
    }

  function test_UnregisterTokenWhenRepeat() public {
        // Mock the registration of the token
        vm.prank(governor);
        bridgeImpl.registerToken(neoXToken, validConfig);

        // Pause the token bridge
        vm.prank(securityGuard);
        bridgeImpl.pauseTokenBridge(neoXToken);

        // Verify the token bridge is paused
        StorageTypes.TokenBridge memory tokenBridgeBefore = bridgeImpl.getTokenbridge(neoXToken);
        assertTrue(tokenBridgeBefore.paused);
        vm.prank(governor);
        bridgeImpl.unregisterToken(neoXToken);

        vm.prank(securityGuard);
        //bridgeImpl.pauseTokenBridge(neoXToken);

        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSelector(BridgeStorage.TokenBridgeUnpaused.selector,neoXToken));
        bridgeImpl.unregisterToken(neoXToken);
    }
}

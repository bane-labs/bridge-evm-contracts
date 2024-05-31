// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../lib/forge-std/src/Test.sol";
import {TestBridge} from "../contracts/tests/TestBridge.sol";
import {BridgeStorage, BridgeLib, GasBridgeLib, StorageTypes, TokenBridgeLib} from "../contracts/bridge/BridgeStorage.sol";
import "../contracts/management/BridgeManagementImpl.sol";
import "../contracts/tests/SigUtils.sol";
import "../contracts/tests/MockERC20.sol";

contract TestFungibleToken is Test, SigUtils {
    // constructor(address _management) BridgeImpl(_management) {}
    TestBridge bridgeImpl;

    address neoXTokenA;
    address neoXTokenB;
    address neoN3TokenA = address(0x7892);
    address neoN3TokenB = address(0x7893);
    StorageTypes.TokenConfig validConfigA;
    StorageTypes.TokenConfig validConfigB;

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
    uint256[] public valid_validatorsKeys;
    address[] public valid_validatorsAddresses;

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
        neoXTokenA = address(new MockERC20("MockA", "MA"));
        neoXTokenB = address(new MockERC20("MockB", "MB"));
        validConfigA = StorageTypes.TokenConfig({
            neoN3Token: neoN3TokenA,
            fee: 1,
            minAmount: 100,
            maxAmount: 1000,
            maxDeposits: 2,
            tokenType: StorageTypes.TokenType.ERC20Capped
        });
        validConfigB = StorageTypes.TokenConfig({
            neoN3Token: neoN3TokenB,
            fee: 1,
            minAmount: 100,
            maxAmount: 1000,
            maxDeposits: 2,
            tokenType: StorageTypes.TokenType.NEO
        });
        vm.deal(user, 1 ether);
        vm.deal(owner, 1 ether);
        vm.deal(owner, 1 ether);
    }

    function testDepositTokenA() public {
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100 ether);
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(user),
            amount: 100,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(owner),
            amount: 200,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;
        bytes32 tokenDepositRoot = bridgeImpl.computeTokenRoot(
            bridgeImpl.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        bridgeImpl.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
        assertEq(MockERC20(neoXTokenA).balanceOf(user), 100);
        assertEq(MockERC20(neoXTokenA).balanceOf(owner), 200);
    }

    function testClaimTokenA() public {
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(user),
            amount: 100,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(owner),
            amount: 200,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;
        bytes32 tokenDepositRoot = bridgeImpl.computeTokenRoot(
            bridgeImpl.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        bridgeImpl.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
        assertEq(MockERC20(neoXTokenA).balanceOf(user), 0);
        assertEq(MockERC20(neoXTokenA).balanceOf(owner), 0);
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100);
        bridgeImpl.claimToken(neoXTokenA, 1);
        assertEq(MockERC20(neoXTokenA).balanceOf(user), 100);
        vm.expectRevert(abi.encodeWithSelector(BridgeStorage.TransferFailed.selector));
        bridgeImpl.claimToken(neoXTokenA, 2);
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 200);
        bridgeImpl.claimToken(neoXTokenA, 2);
        assertEq(MockERC20(neoXTokenA).balanceOf(owner), 200);
        vm.expectRevert(abi.encodeWithSelector(BridgeStorage.NonexistentClaimable.selector));
        bridgeImpl.claimToken(neoXTokenA, 3);
        vm.expectRevert(abi.encodeWithSelector(BridgeStorage.NonexistentClaimable.selector));
        bridgeImpl.claimToken(neoXTokenA, 1);

    }

    function testWithdrawTokenA() public {
        console.log("neoxtoken address: %s,neo address : %s, nonce = 0", neoXTokenA, neoN3TokenA);
        assertEq(bridgeImpl.isRegisteredToken(neoXTokenA), false);
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
        uint balance = 1000;
        MockERC20(neoXTokenA).mint(user, balance);
        MockERC20(neoXTokenA).mint(owner, balance);
        vm.prank(user);
        MockERC20(neoXTokenA).approve(address(bridgeImpl), balance);
        assertEq(MockERC20(neoXTokenA).allowance(user, address(bridgeImpl)), balance);
        vm.prank(owner);
        MockERC20(neoXTokenA).approve(address(bridgeImpl), balance);
        assertEq(MockERC20(neoXTokenA).allowance(owner, address(bridgeImpl)), balance);
        vm.prank(user);
        console.log("user: %s,amount: %d", user,100);
        bridgeImpl.withdrawToken{value: validConfigA.fee}(
            neoXTokenA,
            user,
            100
        );
        vm.prank(user);
        console.log("user: %s,amount: %d", user,200);
        bridgeImpl.withdrawToken{value: validConfigA.fee}(
            neoXTokenA,
            user,
            200
        );
        vm.prank(owner);
        console.log("user: %s,amount: %d", owner,300);
        bridgeImpl.withdrawToken{value: validConfigA.fee}(
            neoXTokenA,
            owner,
            300
        );
        vm.prank(owner);

        console.log("user: %s,amount: %d", owner,400);
        bridgeImpl.withdrawToken{value: validConfigA.fee}(
            neoXTokenA,
            owner,
            400
        );
        assertEq(MockERC20(neoXTokenA).balanceOf(user), balance-300);
        assertEq(MockERC20(neoXTokenA).balanceOf(owner), balance-700);
        //@TODO
        //check withdrwal state and missing max/min deposit amount check in depositToken?
    }

    function getSignatures(
        bytes32 _depositRoot
    ) public view returns (BridgeLib.Signature[] memory) {
        BridgeLib.Signature[] memory _signatures = new BridgeLib.Signature[](5);
        bytes32 ethHash = getSignedHash(_depositRoot);
        for (uint i = 0; i < 5; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                validatorsKeys[i],
                ethHash
            );
            address x = ecrecover(ethHash, v, r, s);
            _signatures[i] = BridgeLib.Signature(v, r, s);
            assertEq(x, validatorsAddresses[i]);
        }
        return _signatures;
    }

    function geterrorSignatures(
        bytes32 _depositRoot
    ) public  returns (BridgeLib.Signature[] memory) {
        sigUtils = new SigUtils();
        valid_validatorsKeys.push(valid_user0PrivateKey);
        valid_validatorsAddresses.push(vm.addr(valid_user0PrivateKey));
        valid_validatorsKeys.push(valid_user1PrivateKey);
        valid_validatorsAddresses.push(vm.addr(valid_user1PrivateKey));
        valid_validatorsKeys.push(valid_user2PrivateKey);
        valid_validatorsAddresses.push(vm.addr(valid_user2PrivateKey));
        valid_validatorsKeys.push(valid_user3PrivateKey);
        valid_validatorsAddresses.push(vm.addr(valid_user3PrivateKey));
        valid_validatorsKeys.push(valid_user4PrivateKey);
        valid_validatorsAddresses.push(vm.addr(valid_user4PrivateKey));
        valid_validatorsKeys.push(valid_user5PrivateKey);
        valid_validatorsAddresses.push(vm.addr(valid_user5PrivateKey));
        valid_validatorsKeys.push(valid_user6PrivateKey);
        valid_validatorsAddresses.push(vm.addr(valid_user6PrivateKey));
        BridgeLib.Signature[] memory _signatures = new BridgeLib.Signature[](5);
        bytes32 ethHash = getSignedHash(_depositRoot);
        for (uint i = 0; i < 5; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                valid_validatorsKeys[i],
                ethHash
            );
            address x = ecrecover(ethHash, v, r, s);
            _signatures[i] = BridgeLib.Signature(v, r, s);
            assertEq(x, valid_validatorsAddresses[i]);
        }
        return _signatures;
    }


    function test_DepositTokenWithInvalidNonceSequence() public {
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100 ether);
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[] memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(user),
            amount: 100,
            nonce: 2
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(owner),
            amount: 200,
            nonce: 1  // Invalid nonce sequence
        });
        depositData[0] = d0;
        depositData[1] = d1;

        bytes32 tokenDepositRoot = bridgeImpl.computeTokenRoot(
            bridgeImpl.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("InvalidNonceSequence()"));
        bridgeImpl.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    }


    function test_DepositTokenWithInvalidRoot() public {
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100 ether);
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(user),
            amount: 100,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(owner),
            amount: 200,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;
        bytes32 tokenDepositRoot = bridgeImpl.computeTokenRoot(
            bridgeImpl.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );

        bytes32 invalidRoot = keccak256(abi.encodePacked(address(0xBAD))); 

        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("InvalidRoot()"));       
        bridgeImpl.depositToken(
            neoXTokenA,
            invalidRoot,
            signatures,
            depositData
        );
    }

    function test_DepositTokenWithInvalidSignatures() public {
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100 ether);
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);        
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(user),
            amount: 100,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(owner),
            amount: 200,
            nonce: 2
        });

        depositData[0] = d0;
        depositData[1] = d1;

        bytes32 tokenDepositRoot = bridgeImpl.computeTokenRoot(
            bridgeImpl.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );

        BridgeLib.Signature[] memory signatures = geterrorSignatures(
            tokenDepositRoot
        );

        // Expect revert
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("InvalidValidatorSignatures()"));
        bridgeImpl.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    }


// todo deposittoken到底需不需要relayer
    function testFailDepositTokenByNonRelayer() public {
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100 ether);
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(user),
            amount: 100,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(owner),
            amount: 200,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;
        bytes32 tokenDepositRoot = bridgeImpl.computeTokenRoot(
            bridgeImpl.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(address(0x9541)); // Non-relayer address
        // vm.expectRevert("not relayer");
        bridgeImpl.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    }

    function test_DepositTokenWithInvalidLength() public {
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100 ether);
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[] memory depositData = new BridgeLib.DepositData[](0); // Invalid length
        bytes32 tokenDepositRoot = bridgeImpl.computeTokenRoot(
            bridgeImpl.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("InvalidDepositsLength()"));
        bridgeImpl.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    }
    

    function test_DepositTokenWithExceedMaxDeposits() public {
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100 ether);
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[] memory depositData = new BridgeLib.DepositData[](3);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(user),
            amount: 100,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(owner),
            amount: 200,
            nonce: 2 
        });
        BridgeLib.DepositData memory d2 = BridgeLib.DepositData({
            to: payable(governor),
            amount: 200,
            nonce: 3  
        });
        depositData[0] = d0;
        depositData[1] = d1;

        bytes32 tokenDepositRoot = bridgeImpl.computeTokenRoot(
            bridgeImpl.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("InvalidDepositsLength()"));
        bridgeImpl.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    } 

    function test_DepositTokenWithTokenBridgepaused() public {
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100 ether);
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
        vm.prank(securityGuard);
        bridgeImpl.pauseTokenBridge(neoXTokenA);
        // Verify the token bridge is paused
        StorageTypes.TokenBridge memory tokenBridgeAfter = bridgeImpl.getTokenbridge(neoXTokenA);
        assertTrue(tokenBridgeAfter.paused);
        BridgeLib.DepositData[] memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(user),
            amount: 100,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(owner),
            amount: 200,
            nonce: 2 
        });
        depositData[0] = d0;
        depositData[1] = d1;

        bytes32 tokenDepositRoot = bridgeImpl.computeTokenRoot(
            bridgeImpl.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("TokenBridgePaused(address)", neoXTokenA));
        bridgeImpl.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    }  


    function test_DepositTokenWithbridgePaused() public {
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100 ether);
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
        assertFalse(bridgeImpl.getbridgePaused());
        vm.prank(securityGuard);
        bridgeImpl.pauseBridge();
        assertTrue(bridgeImpl.getbridgePaused());
        BridgeLib.DepositData[] memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(user),
            amount: 100,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(owner),
            amount: 200,
            nonce: 2 
        });
        depositData[0] = d0;
        depositData[1] = d1;

        bytes32 tokenDepositRoot = bridgeImpl.computeTokenRoot(
            bridgeImpl.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("BridgePaused()"));
        bridgeImpl.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
        vm.prank(governor);
        bridgeImpl.unpauseBridge();
        assertFalse(bridgeImpl.getbridgePaused());
    }        
  
}

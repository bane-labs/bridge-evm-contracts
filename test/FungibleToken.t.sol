// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BridgeMigrations} from "./migrations/BridgeMigrations.sol";
import {ManagementMigrations} from "./migrations/ManagementMigrations.sol";
import {BridgeStorage, BridgeLib, GasBridgeLib, StorageTypes, TokenBridgeLib} from "../contracts/bridge/BridgeStorage.sol";
import {ITokenBridge} from "../contracts/interfaces/ITokenBridge.sol";
import {MockERC20} from "../contracts/tests/MockERC20.sol";
import {SigUtils} from "../contracts/tests/SigUtils.sol";
import {TestBridgeManagement} from "../contracts/tests/TestBridgeManagement.sol";
import {TestBridgeV1ToV2} from "../contracts/tests/migrations/TestBridgeV1ToV2.sol";
import {TestManagementV1ToV2} from "../contracts/tests/migrations/TestManagementV1ToV2.sol";
import {Test} from "../lib/forge-std/src/Test.sol";

contract TestFungibleToken is Test, SigUtils {
    TestBridgeV1ToV2 bridgeProxy;
    address managementProxyAddress;
    address bridgeProxyAddress;

    address neoXTokenA;
    address neoXTokenB;
    address neoN3TokenA = address(0x7892);
    address neoN3TokenB = address(0x7893);
    StorageTypes.TokenConfig validConfigA;
    StorageTypes.TokenConfig validConfigB;

    // set _management
    TestManagementV1ToV2 managementProxy;
    SigUtils sigUtils;
    address public owner = 0xBcd4042DE499D14e55001CcbB24a551F3b954096;
    address public funder = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public relayer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint8 public validatorThreshold = 5;
    uint256[] public validatorsKeys;
    address[] public validatorsAddresses;
    address internal governor = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    address internal securityGuard = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
    uint256[] public valid_validatorsKeys;
    address[] public valid_validatorsAddresses;
    address transferUser0 = 0xF3D4D6320dd41f14B8Fa6550a6F33c46c6F44407;
    address transferUser1 = 0x3220a7ee654E1f84f13E8021B7E2b09775E1BDf2;

    function setUp() public {
        //set _management
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

        // Allow constructor to bypass the safety check in deployUUPSProxy.
        // The constructor only contains _disableInitializers() which is safe to bypass.
        Options memory opts;
        opts.unsafeAllow = "constructor";

        // Deploy the management behind a proxy and upgrade it to the latest implementation.
        managementProxyAddress = ManagementMigrations.deployManagementV1ToV2(
            owner,
            relayer,
            5,
            validatorsAddresses,
            governor,
            securityGuard,
            funder,
            opts
        );
        managementProxy = TestManagementV1ToV2(managementProxyAddress);
        // Validate that the management proxy has been successfully deployed and upgraded to V2.abi
        assertEq(managementProxy.getCurrentInitializedVersion(), 2);

        // Deploy the bridge including upgrade steps to V2.
        bridgeProxyAddress = BridgeMigrations.deployBridgeV1ToV2(
            managementProxyAddress,
            opts
        );
        bridgeProxy = TestBridgeV1ToV2(payable(bridgeProxyAddress));
        // Validate that the bridge proxy has been successfully deployed and upgraded to V2.
        assertEq(bridgeProxy.getCurrentInitializedVersion(), 2);

        neoXTokenA = address(new MockERC20("MockA", "MA"));
        neoXTokenB = address(new MockERC20("MockB", "MB"));
        validConfigA = StorageTypes.TokenConfig({
            neoN3Token: neoN3TokenA,
            decimalScalingFactor: 0,
            fee: 1,
            minAmount: 100,
            maxAmount: 1000,
            maxDeposits: 2
        });
        validConfigB = StorageTypes.TokenConfig({
            neoN3Token: neoN3TokenB,
            decimalScalingFactor: 18,
            fee: 1,
            minAmount: 100,
            maxAmount: 1000 ether,
            maxDeposits: 2
        });

        // Fund the test accounts with some ether.
        vm.deal(funder, 1 ether);
        vm.deal(owner, 1 ether);
        vm.deal(transferUser0, 1 ether);
        vm.deal(transferUser1, 1 ether);
    }

    // Get the correct signatures of the five validators
    function getSignatures(
        bytes32 _depositRoot
    ) public view returns (BridgeLib.Signature[] memory) {
        uint[] memory defaultIndices = new uint[](5);
        for (uint i = 0; i < 5; i++) {
            defaultIndices[i] = i;
        }
        return getSignatures(_depositRoot, defaultIndices);
    }

    // Get the correct signatures of the five/six/seven validators
    function getSignatures(
        bytes32 _depositRoot,
        uint[] memory validatorIndices
    ) public view returns (BridgeLib.Signature[] memory) {
        // Ensure that the length of the validatorIndices array passed in is 5,6,7, otherwise an exception is thrown
        require(
            validatorIndices.length == 5 ||
                validatorIndices.length == 6 ||
                validatorIndices.length == 7,
            "five-seven validator indexes must be provided"
        );

        BridgeLib.Signature[] memory _signatures = new BridgeLib.Signature[](
            validatorIndices.length
        );
        bytes32 ethHash = getSignedHash(_depositRoot);

        for (uint i = 0; i < validatorIndices.length; i++) {
            uint validatorIndex = validatorIndices[i];
            require(validatorIndex < validatorsKeys.length, "Invalid index");

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                validatorsKeys[validatorIndex],
                ethHash
            );

            address recoverAddress = ecrecover(ethHash, v, r, s);
            _signatures[i] = BridgeLib.Signature(v, r, s);
            assertEq(recoverAddress, validatorsAddresses[validatorIndex]);
        }
        return _signatures;
    }

    // test case: successful deposit token, token type is ERC20, Let's call it deposit token A, takes the signatures of the first 5 validators，and check the event
    function testDepositTokenA() public {
        MockERC20(neoXTokenA).mint(address(bridgeProxy), 100 ether);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: 700,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(transferUser1),
            amount: 800,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;
        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        // check event
        vm.expectEmit(true, true, true, true);
        emit ITokenBridge.TokenDepositRootUpdate(
            address(neoXTokenA),
            address(neoN3TokenA),
            d1.nonce,
            tokenDepositRoot
        );
        bridgeProxy.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
        // check balance
        assertEq(MockERC20(neoXTokenA).balanceOf(transferUser0), 700);
        assertEq(MockERC20(neoXTokenA).balanceOf(transferUser1), 800);
    }

    // test case: successful deposit token, token type is NEO, Let's call it deposit token B, takes the signatures of the random 6 validators
    function testDepositTokenB() public {
        // Verify the signatures of 6 validators
        vm.prank(owner);
        managementProxy.setValidatorThreshold(6);

        // managementProxy.setValidators(validatorsAddresses, 6);

        MockERC20(neoXTokenB).mint(address(bridgeProxy), 1000 ether);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenB, validConfigB);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: 355,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(transferUser1),
            amount: 445,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;
        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenB).root,
            neoN3TokenB,
            neoXTokenB,
            depositData
        );
        // takes the signatures of the random 6 validators
        uint[] memory validatorIndices = new uint[](6);
        validatorIndices[0] = 0;
        validatorIndices[1] = 1;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        validatorIndices[5] = 6;
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot,
            validatorIndices
        );
        vm.prank(relayer);
        // check event
        emit ITokenBridge.TokenDepositRootUpdate(
            address(neoXTokenB),
            address(neoN3TokenB),
            d1.nonce,
            tokenDepositRoot
        );
        bridgeProxy.depositToken(
            neoXTokenB,
            tokenDepositRoot,
            signatures,
            depositData
        );
        // check balances
        assertEq(MockERC20(neoXTokenB).balanceOf(transferUser0), 355 ether);
        assertEq(MockERC20(neoXTokenB).balanceOf(transferUser1), 445 ether);
    }

    // some test case, token type is ERC20, Let's call it claim token A, seven validator participate in the verification
    function testClaimTokenA() public {
        // Verify the signatures of 7 validators
        vm.prank(owner);
        managementProxy.setValidatorThreshold(7);
        // managementProxy.setValidators(validatorsAddresses, 7);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: 199,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(transferUser1),
            amount: 299,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;
        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        // seven validator participate in the verification
        uint[] memory validatorIndices = new uint[](7);
        for (uint i = 0; i < validatorIndices.length; i++) {
            validatorIndices[i] = i;
        }
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot,
            validatorIndices
        );
        vm.prank(relayer);
        bridgeProxy.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
        assertEq(MockERC20(neoXTokenA).balanceOf(transferUser0), 0);
        assertEq(MockERC20(neoXTokenA).balanceOf(transferUser1), 0);

        // test case: claim token A nonce 1 successful
        MockERC20(neoXTokenA).mint(address(bridgeProxy), 199);
        bridgeProxy.claimToken(neoXTokenA, 1);
        assertEq(MockERC20(neoXTokenA).balanceOf(transferUser0), 199);

        // test case: claim token A nonce 2 failed, bridge have not enough token
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(bridgeProxy),
                0,
                299
            )
        );
        bridgeProxy.claimToken(neoXTokenA, 2);

        // test case: claim token A nonce 2 successful
        MockERC20(neoXTokenA).mint(address(bridgeProxy), 299);
        bridgeProxy.claimToken(neoXTokenA, 2);
        assertEq(MockERC20(neoXTokenA).balanceOf(transferUser1), 299);

        // test case: claim token A not exit nonce 3 failed
        vm.expectRevert(
            abi.encodeWithSelector(BridgeStorage.NonexistentClaimable.selector)
        );
        bridgeProxy.claimToken(neoXTokenA, 3);

        // test case:non-repeatable claim token
        vm.expectRevert(
            abi.encodeWithSelector(BridgeStorage.NonexistentClaimable.selector)
        );
        bridgeProxy.claimToken(neoXTokenA, 1);
    }

    // some test case, token type is NEO, Let's call it claim token B, takes the signatures of the random 5 validators
    function testClaimTokenB() public {
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenB, validConfigB);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: 438,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(transferUser1),
            amount: 439,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;
        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenB).root,
            neoN3TokenB,
            neoXTokenB,
            depositData
        );
        // takes the signatures of the random 5 validators
        uint[] memory validatorIndices = new uint[](5);
        validatorIndices[1] = 1;
        validatorIndices[1] = 3;
        validatorIndices[1] = 4;
        validatorIndices[1] = 5;
        validatorIndices[1] = 6;
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        bridgeProxy.depositToken(
            neoXTokenB,
            tokenDepositRoot,
            signatures,
            depositData
        );
        assertEq(MockERC20(neoXTokenB).balanceOf(transferUser0), 0);
        assertEq(MockERC20(neoXTokenB).balanceOf(transferUser1), 0);

        // test case: claim token B nonce 1 successful
        MockERC20(neoXTokenB).mint(address(bridgeProxy), 438 ether);
        bridgeProxy.claimToken(neoXTokenB, 1);
        assertEq(MockERC20(neoXTokenB).balanceOf(transferUser0), 438 ether);

        // test case: claim token B nonce 2 failed, bridge have not enough token
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(bridgeProxy),
                0,
                439 ether
            )
        );
        bridgeProxy.claimToken(neoXTokenB, 2);

        // test case: claim token B nonce 2 successful
        MockERC20(neoXTokenB).mint(address(bridgeProxy), 439 ether);
        bridgeProxy.claimToken(neoXTokenB, 2);
        assertEq(MockERC20(neoXTokenB).balanceOf(transferUser1), 439 ether);

        // test case: claim token B not exit nonce 3 failed
        vm.expectRevert(
            abi.encodeWithSelector(BridgeStorage.NonexistentClaimable.selector)
        );
        bridgeProxy.claimToken(neoXTokenB, 3);

        // test case:non-repeatable claim token
        vm.expectRevert(
            abi.encodeWithSelector(BridgeStorage.NonexistentClaimable.selector)
        );
        bridgeProxy.claimToken(neoXTokenB, 1);
    }

    // test case: successful withdraw token, token type is ERC20, Let's call it withdraw token A
    function testWithdrawTokenA() public {
        assertEq(bridgeProxy.isRegisteredToken(neoXTokenA), false);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        uint balance = 1000;
        MockERC20(neoXTokenA).mint(transferUser0, balance);
        MockERC20(neoXTokenA).mint(transferUser1, balance);
        vm.prank(transferUser0);
        MockERC20(neoXTokenA).approve(address(bridgeProxy), balance);
        assertEq(
            MockERC20(neoXTokenA).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            balance
        );
        vm.prank(transferUser1);
        MockERC20(neoXTokenA).approve(address(bridgeProxy), balance);
        assertEq(
            MockERC20(neoXTokenA).allowance(
                transferUser1,
                address(bridgeProxy)
            ),
            balance
        );
        vm.prank(transferUser0);
        bridgeProxy.withdrawToken{value: validConfigA.fee}(
            neoXTokenA,
            transferUser0,
            666
        );
        vm.prank(transferUser0);
        bridgeProxy.withdrawToken{value: validConfigA.fee}(
            neoXTokenA,
            transferUser0,
            111
        );
        vm.prank(transferUser1);
        bridgeProxy.withdrawToken{value: validConfigA.fee}(
            neoXTokenA,
            transferUser1,
            777
        );
        vm.prank(transferUser1);
        bridgeProxy.withdrawToken{value: validConfigA.fee}(
            neoXTokenA,
            transferUser1,
            111
        );
        assertEq(MockERC20(neoXTokenA).balanceOf(transferUser0), balance - 777);
        assertEq(MockERC20(neoXTokenA).balanceOf(transferUser1), balance - 888);
    }

    // test case: successful withdraw token, token type is NEO, Let's call it withdraw token B
    function testWithdrawTokenB() public {
        assertEq(bridgeProxy.isRegisteredToken(neoXTokenB), false);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenB, validConfigB);
        uint balance = 1000 ether;
        MockERC20(neoXTokenB).mint(transferUser0, balance);
        MockERC20(neoXTokenB).mint(transferUser1, balance);
        vm.prank(transferUser0);
        MockERC20(neoXTokenB).approve(address(bridgeProxy), balance);
        assertEq(
            MockERC20(neoXTokenB).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            balance
        );
        vm.prank(transferUser1);
        MockERC20(neoXTokenB).approve(address(bridgeProxy), balance);
        assertEq(
            MockERC20(neoXTokenB).allowance(
                transferUser1,
                address(bridgeProxy)
            ),
            balance
        );
        vm.prank(transferUser0);
        bridgeProxy.withdrawToken{value: validConfigB.fee}(
            neoXTokenB,
            transferUser0,
            135 ether
        );
        vm.prank(transferUser0);
        bridgeProxy.withdrawToken{value: validConfigB.fee}(
            neoXTokenB,
            transferUser0,
            165 ether
        );
        vm.prank(transferUser1);
        bridgeProxy.withdrawToken{value: validConfigB.fee}(
            neoXTokenB,
            transferUser1,
            337 ether
        );
        vm.prank(transferUser1);
        bridgeProxy.withdrawToken{value: validConfigB.fee}(
            neoXTokenB,
            transferUser1,
            363 ether
        );

        vm.prank(transferUser1);
        vm.expectRevert(BridgeStorage.InvalidAmount.selector);
        bridgeProxy.withdrawToken{value: validConfigB.fee}(
            neoXTokenB,
            transferUser1,
            1 ether + 100
        );
        assertEq(
            MockERC20(neoXTokenB).balanceOf(transferUser0),
            balance - 300 ether
        );
        assertEq(
            MockERC20(neoXTokenB).balanceOf(transferUser1),
            balance - 700 ether
        );
    }

    // Get the error signatures of the five validators
    function geterrorSignatures(
        bytes32 _depositRoot
    ) public returns (BridgeLib.Signature[] memory) {
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

    // test case: successful withdraw token, token type is NEO, Let's call it withdraw token B
    function test_DepositTokenWithInvalidNonceSequence() public {
        MockERC20(neoXTokenA).mint(address(bridgeProxy), 100 ether);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: 100,
            nonce: 2
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(transferUser1),
            amount: 200,
            nonce: 1 // Invalid nonce sequence
        });
        depositData[0] = d0;
        depositData[1] = d1;

        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("InvalidNonceSequence()"));
        bridgeProxy.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    }

    // test case: deposit token failed when DepositRoot is invalid
    function test_DepositTokenWithInvalidRoot() public {
        MockERC20(neoXTokenA).mint(address(bridgeProxy), 100 ether);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: 45,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(transferUser1),
            amount: 65,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;
        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
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
        bridgeProxy.depositToken(
            neoXTokenA,
            invalidRoot,
            signatures,
            depositData
        );
    }

    // test case: deposit token failed when signatures is invalid
    function test_DepositTokenWithInvalidSignatures() public {
        MockERC20(neoXTokenA).mint(address(bridgeProxy), 100 ether);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);

        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: 65,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(transferUser1),
            amount: 78,
            nonce: 2
        });

        depositData[0] = d0;
        depositData[1] = d1;

        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );

        BridgeLib.Signature[] memory signatures = geterrorSignatures(
            tokenDepositRoot
        );

        // Expect revert
        vm.prank(relayer);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidValidatorSignatures()")
        );
        bridgeProxy.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    }

    // test case: deposit token failed because it is not relayer
    function test_DepositTokenByNonRelayer() public {
        MockERC20(neoXTokenA).mint(address(bridgeProxy), 100 ether);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: 100,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(transferUser1),
            amount: 200,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;
        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(address(0x9541)); // Non-relayer address
        vm.expectRevert("not relayer");
        bridgeProxy.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    }

    // test case: deposit token failed when depositData is null
    function test_DepositTokenWithInvalidLength() public {
        MockERC20(neoXTokenA).mint(address(bridgeProxy), 100 ether);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](0); // Invalid length
        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("InvalidDepositsLength()"));
        bridgeProxy.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    }

    // Test case: Deposit token failed when depositData length exceeds bridge configuration
    function test_DepositTokenWithExceedMaxDeposits() public {
        MockERC20(neoXTokenA).mint(address(bridgeProxy), 100 ether);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](3);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: 55,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(transferUser1),
            amount: 65,
            nonce: 2
        });
        BridgeLib.DepositData memory d2 = BridgeLib.DepositData({
            to: payable(governor),
            amount: 75,
            nonce: 3
        });
        depositData[0] = d0;
        depositData[1] = d1;
        depositData[2] = d2;
        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("InvalidDepositsLength()"));
        bridgeProxy.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    }

    // Test case: Deposit token failed when token is paused
    function test_DepositTokenWithTokenBridgepaused() public {
        MockERC20(neoXTokenA).mint(address(bridgeProxy), 100 ether);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        vm.prank(securityGuard);
        bridgeProxy.pauseTokenBridge(neoXTokenA);
        // Verify the token bridge is paused
        bool tokenBridgePaused = bridgeProxy.getTokenbridgePaused(neoXTokenA);
        assertTrue(tokenBridgePaused);
        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: 100,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(transferUser1),
            amount: 200,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;

        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectRevert(
            abi.encodeWithSignature("TokenBridgePaused(address)", neoXTokenA)
        );
        bridgeProxy.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
    }

    // Test case: Deposit token failed when bridge is paused
    function test_DepositTokenWithbridgePaused() public {
        MockERC20(neoXTokenA).mint(address(bridgeProxy), 100 ether);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        assertFalse(bridgeProxy.getbridgePaused());

        vm.prank(securityGuard);
        bridgeProxy.pauseBridge();
        assertTrue(bridgeProxy.getbridgePaused());

        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: 54,
            nonce: 1
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            to: payable(transferUser1),
            amount: 65,
            nonce: 2
        });
        depositData[0] = d0;
        depositData[1] = d1;

        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("BridgePaused()"));
        bridgeProxy.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
        vm.prank(governor);

        bridgeProxy.unpauseBridge();
        assertFalse(bridgeProxy.getbridgePaused());
    }

    // Test case: Withdrawals should be rejected while withdrawals are paused
    function test_RejectWithdrawalsWhileWithdrawalsPaused() public {
        MockERC20(neoXTokenA).mint(address(transferUser0), 10000);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        assertFalse(bridgeProxy.getWithdrawalsPaused());

        uint256 allowance = 500;
        vm.prank(transferUser0);
        MockERC20(neoXTokenA).approve(address(bridgeProxy), allowance);
        assertEq(
            MockERC20(neoXTokenA).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            allowance
        );

        uint256 fee = bridgeProxy.getTokenConfig(neoXTokenA).fee;
        uint256 transferAmount = 200;
        vm.prank(transferUser0);
        bridgeProxy.withdrawToken{value: fee}(
            neoXTokenA,
            transferUser1,
            transferAmount
        );
        assertEq(
            MockERC20(neoXTokenA).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            allowance - transferAmount
        );

        vm.prank(governor);
        bridgeProxy.pauseWithdrawals();
        assertTrue(bridgeProxy.getWithdrawalsPaused());

        vm.expectRevert(abi.encodeWithSignature("WithdrawalsPaused()"));
        bridgeProxy.withdrawToken(neoXTokenA, transferUser0, transferAmount);
    }

    // Test case: Deposits should be allowed while withdrawals are paused
    function test_DepositsAreAllowedWhileWithdrawalsPaused() public {
        uint256 initialBridgeBalance = 10000;
        MockERC20(neoXTokenA).mint(address(bridgeProxy), initialBridgeBalance);
        assertEq(
            MockERC20(neoXTokenA).balanceOf(address(bridgeProxy)),
            initialBridgeBalance
        );
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        assertFalse(bridgeProxy.getWithdrawalsPaused());
        vm.prank(governor);
        bridgeProxy.pauseWithdrawals();
        assertTrue(bridgeProxy.getWithdrawalsPaused());

        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](1);
        uint256 depositAmount = 700;
        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            to: payable(transferUser0),
            amount: depositAmount,
            nonce: 1
        });
        depositData[0] = d0;
        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
            neoN3TokenA,
            neoXTokenA,
            depositData
        );
        BridgeLib.Signature[] memory signatures = getSignatures(
            tokenDepositRoot
        );
        vm.prank(relayer);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridge.TokenDepositRootUpdate(
            address(neoXTokenA),
            address(neoN3TokenA),
            d0.nonce,
            tokenDepositRoot
        );
        bridgeProxy.depositToken(
            neoXTokenA,
            tokenDepositRoot,
            signatures,
            depositData
        );
        // check balance
        assertEq(
            MockERC20(neoXTokenA).balanceOf(address(bridgeProxy)),
            initialBridgeBalance - depositAmount
        );
        assertEq(MockERC20(neoXTokenA).balanceOf(transferUser0), depositAmount);
    }

    // test case: withdraw token failed when insufficient fee
    function testWithdrawToken_InsufficientFee() public {
        assertEq(bridgeProxy.isRegisteredToken(neoXTokenA), false);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        uint balance = 1000;
        MockERC20(neoXTokenA).mint(transferUser0, balance);
        vm.prank(transferUser0);
        MockERC20(neoXTokenA).approve(address(bridgeProxy), balance);
        assertEq(
            MockERC20(neoXTokenA).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            balance
        );
        // Set an insufficient fee
        uint256 providedFee = validConfigA.fee - 1;
        vm.expectRevert(
            abi.encodeWithSignature(
                "InsufficientFee(uint256,uint256)",
                validConfigA.fee,
                providedFee
            )
        );
        vm.prank(transferUser0);
        bridgeProxy.withdrawToken{value: providedFee}(
            neoXTokenA,
            transferUser0,
            100
        );
    }

    // test case: withdraw token with too high fee - refunded
    function testWithdrawToken_refundExcessFee() public {
        assertEq(bridgeProxy.isRegisteredToken(neoXTokenA), false);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        uint256 balance = 1000;
        MockERC20(neoXTokenA).mint(transferUser0, balance);
        vm.prank(transferUser0);
        MockERC20(neoXTokenA).approve(address(bridgeProxy), balance);
        assertEq(
            MockERC20(neoXTokenA).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            balance
        );
        // Set an excess fee
        uint256 excessFee = 0.5 ether;
        uint256 providedFee = validConfigA.fee + excessFee;
        uint256 gasBalanceBridgeBefore = address(bridgeProxy).balance;

        vm.prank(transferUser0);
        bridgeProxy.withdrawToken{value: providedFee}(
            neoXTokenA,
            transferUser0,
            100
        );

        assertEq(
            address(bridgeProxy).balance,
            gasBalanceBridgeBefore + validConfigA.fee
        );
        assertEq(bridgeProxy.unclaimedRewards(), validConfigA.fee);
    }

    // test case: withdraw token failed when amount < minAmount
    function testWithdrawToken_InvalidAmount_LessThanMin() public {
        assertEq(bridgeProxy.isRegisteredToken(neoXTokenA), false);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        uint balance = 1000;
        MockERC20(neoXTokenA).mint(transferUser0, balance);
        vm.prank(transferUser0);
        MockERC20(neoXTokenA).approve(address(bridgeProxy), balance);
        assertEq(
            MockERC20(neoXTokenA).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            balance
        );
        uint256 amount = validConfigA.minAmount - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                BridgeStorage.AmountBelowMinAmount.selector,
                [validConfigA.minAmount, amount]
            )
        );
        vm.prank(transferUser0);
        bridgeProxy.withdrawToken{value: validConfigA.fee}(
            address(neoXTokenA),
            transferUser0,
            amount
        );
    }

    // test case: withdraw token failed when amount > maxAmount
    function testWithdrawToken_InvalidAmount_MoreThanMaxl() public {
        assertEq(bridgeProxy.isRegisteredToken(neoXTokenA), false);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        uint balance = 1001;
        MockERC20(neoXTokenA).mint(transferUser0, balance);
        vm.prank(transferUser0);
        MockERC20(neoXTokenA).approve(address(bridgeProxy), balance);
        assertEq(
            MockERC20(neoXTokenA).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            balance
        );
        uint256 amount = validConfigA.maxAmount + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                BridgeStorage.AmountExceedsMaxAmount.selector,
                [validConfigA.maxAmount, amount]
            )
        );
        vm.prank(transferUser0);
        bridgeProxy.withdrawToken{value: validConfigA.fee}(
            address(neoXTokenA),
            transferUser0,
            amount
        );
    }

    // test case: withdraw token failed when amount > approveAmount
    function testWithdrawToken_TransferFailed() public {
        assertEq(bridgeProxy.isRegisteredToken(neoXTokenA), false);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        uint balance = 1000;
        uint approveAmount = 100;
        MockERC20(neoXTokenA).mint(transferUser0, balance);
        vm.prank(transferUser0);
        MockERC20(neoXTokenA).approve(address(bridgeProxy), approveAmount);
        assertEq(
            MockERC20(neoXTokenA).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            approveAmount
        );
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                address(bridgeProxy),
                approveAmount,
                balance
            )
        );
        vm.prank(transferUser0);
        bridgeProxy.withdrawToken{value: validConfigA.fee}(
            address(neoXTokenA),
            transferUser0,
            balance
        );
    }

    // test case:withdraw token failed when token bridge not registered
    function testWithdrawToken_UnregisteredToken() public {
        MockERC20 unregisteredToken = new MockERC20("MockA", "MA");
        vm.expectRevert(
            abi.encodeWithSignature(
                "TokenBridgeNotRegistered(address)",
                address(unregisteredToken)
            )
        );
        bridgeProxy.withdrawToken{value: validConfigA.fee}(
            address(unregisteredToken),
            transferUser0,
            100
        );
    }

    // test case:  withdraw token B failed , token type is NEO,tokenvalue < 1e18
    function testWithdrawTokenB_TransferFailed() public {
        assertEq(bridgeProxy.isRegisteredToken(neoXTokenB), false);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenB, validConfigB);
        uint balance = 1000 ether;
        MockERC20(neoXTokenB).mint(transferUser0, balance);
        vm.prank(transferUser0);
        MockERC20(neoXTokenB).approve(address(bridgeProxy), balance);
        assertEq(
            MockERC20(neoXTokenB).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            balance
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        vm.prank(transferUser0);
        bridgeProxy.withdrawToken{value: validConfigB.fee}(
            neoXTokenB,
            transferUser0,
            1000000
        );
    }

    // test case: Check the event that withdraw token A succeeds
    function testWithdrawATokenEvent() public {
        assertEq(bridgeProxy.isRegisteredToken(neoXTokenA), false);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenA, validConfigA);
        uint balance = 1000;
        MockERC20(neoXTokenA).mint(transferUser0, balance);
        vm.prank(transferUser0);
        MockERC20(neoXTokenA).approve(address(bridgeProxy), balance);
        assertEq(
            MockERC20(neoXTokenA).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            balance
        );
        // caculate withdrawalHash
        bytes32 withdrawalHash = TokenBridgeLib._hashTokenBridgeOp(
            neoN3TokenA,
            neoXTokenA,
            1,
            transferUser0,
            342
        );
        // caculate newRoot
        bytes32 newRoot = BridgeLib._computeNewRoot(
            bridgeProxy.getTokenDepositState(neoXTokenA).root,
            withdrawalHash
        );
        // check withdraw token event
        vm.prank(transferUser0);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridge.TokenWithdrawal(
            address(neoXTokenA),
            address(neoN3TokenA),
            1,
            transferUser0,
            342,
            transferUser0,
            withdrawalHash,
            newRoot
        );
        bridgeProxy.withdrawToken{value: validConfigA.fee}(
            neoXTokenA,
            transferUser0,
            342
        );
    }

    // test case: Check the event that withdraw token B succeeds
    function testWithdrawBTokenEvent() public {
        assertEq(bridgeProxy.isRegisteredToken(neoXTokenB), false);
        vm.prank(governor);
        bridgeProxy.registerToken(neoXTokenB, validConfigB);
        uint balance = 1000 ether;
        MockERC20(neoXTokenB).mint(transferUser0, balance);
        vm.prank(transferUser0);
        MockERC20(neoXTokenB).approve(address(bridgeProxy), balance);
        assertEq(
            MockERC20(neoXTokenB).allowance(
                transferUser0,
                address(bridgeProxy)
            ),
            balance
        );
        // caculate withdrawalHash
        bytes32 withdrawalHash = TokenBridgeLib._hashTokenBridgeOp(
            neoN3TokenB,
            neoXTokenB,
            1,
            transferUser0,
            233
        );
        // caculate newRoot
        bytes32 newRoot = BridgeLib._computeNewRoot(
            bridgeProxy.getTokenDepositState(neoXTokenB).root,
            withdrawalHash
        );
        // check withdraw token event
        vm.prank(transferUser0);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridge.TokenWithdrawal(
            address(neoXTokenB),
            address(neoN3TokenB),
            1,
            transferUser0,
            233,
            transferUser0,
            withdrawalHash,
            newRoot
        );
        bridgeProxy.withdrawToken{value: validConfigB.fee}(
            neoXTokenB,
            transferUser0,
            233 ether
        );
    }
}

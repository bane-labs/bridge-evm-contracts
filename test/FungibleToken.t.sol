// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../lib/forge-std/src/Test.sol";
import {TestBridge} from "../contracts/tests/TestBridge.sol";
import {BridgeStorage,BridgeLib,GasBridgeLib,StorageTypes,TokenBridgeLib} from "../contracts/bridge/BridgeStorage.sol";
import "../contracts/management/BridgeManagementImpl.sol";
import "../contracts/tests/SigUtils.sol";
import "../contracts/tests/MockERC20.sol";

contract TestFungibleToken is Test,SigUtils {
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
        neoXTokenA = address(new MockERC20("MockA","MA"));
        neoXTokenB = address(new MockERC20("MockB","MB"));
        validConfigA = StorageTypes.TokenConfig({
            neoN3Token: neoN3TokenA,
            fee: 1,
            minAmount: 100,
            maxAmount: 1000,
            maxDeposits: 10,
            tokenType: StorageTypes.TokenType.ERC20Capped
        });
        validConfigB = StorageTypes.TokenConfig({
            neoN3Token: neoN3TokenB,
            fee: 1,
            minAmount: 100,
            maxAmount: 1000,
            maxDeposits: 10,
            tokenType: StorageTypes.TokenType.NEO
        });


    }

    function testDepositTokenASuccess() public {
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100 ether);
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
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
        BridgeLib.Signature[] memory signatures = getSignatures(tokenDepositRoot);
        bridgeImpl.depositToken(neoXTokenA,tokenDepositRoot, signatures,depositData);
        assertEq(MockERC20(neoXTokenA).balanceOf(user), 100);
        assertEq(MockERC20(neoXTokenA).balanceOf(owner), 200);
    }

    function testClaimTokenASuccess() public {
        vm.prank(governor);
        bridgeImpl.registerToken(neoXTokenA, validConfigA);
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
        BridgeLib.Signature[] memory signatures = getSignatures(tokenDepositRoot);
        bridgeImpl.depositToken(neoXTokenA,tokenDepositRoot, signatures,depositData);
        assertEq(MockERC20(neoXTokenA).balanceOf(user), 0);
        assertEq(MockERC20(neoXTokenA).balanceOf(owner), 0);
        MockERC20(neoXTokenA).mint(address(bridgeImpl), 100 ether);
        bridgeImpl.claimToken(neoXTokenA,1);
        assertEq(MockERC20(neoXTokenA).balanceOf(user), 100);
         bridgeImpl.claimToken(neoXTokenA,2);
        assertEq(MockERC20(neoXTokenA).balanceOf(owner), 200);


    }

    function getSignatures(bytes32 _depositRoot) public view returns (BridgeLib.Signature[] memory){
        BridgeLib.Signature[] memory _signatures = new BridgeLib.Signature[](5);
        bytes32 ethHash = getSignedHash(_depositRoot);
        for (uint i = 0; i < 5; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorsKeys[i], ethHash);
            address x = ecrecover(ethHash, v, r, s);
            _signatures[i] = BridgeLib.Signature(v, r, s);
            assertEq(x, validatorsAddresses[i]);
        }
        return _signatures;
    }





}
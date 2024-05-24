pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../contracts/management/BridgeManagementImpl.sol";
import "../contracts/tests/SigUtils.sol";
import "../contracts/library/BridgeLib.sol";

contract BridgeManagementImplTest is Test, SigUtils {
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
    }





    function testSetOwner() public {
        assertEq(bridgeManagementImpl.getOwner(), owner);
        vm.expectRevert(bytes("Not owner"));
        bridgeManagementImpl.setOwner(user);
        vm.prank(owner);
        bridgeManagementImpl.setOwner(user);
        assertEq(bridgeManagementImpl.getOwner(), user);
    }

    function testVerifyValidatorSignatures() public {
        BridgeLib.DepositData memory d = BridgeLib.DepositData({
            to: payable(user),
            amount: 100,
            nonce: 1
        });
        bytes32 _depositRoot = getStructHash(d);
        BridgeLib.Signature[] memory _signatures = new BridgeLib.Signature[](5);
        bytes32 ethHash = getSignedHash(_depositRoot);
        for (uint i = 0; i < 5; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorsKeys[i], ethHash);
            address x = ecrecover(ethHash, v, r, s);
            _signatures[i] = BridgeLib.Signature(v, r, s);
            assertEq(x, validatorsAddresses[i]);
        }
        assert(bridgeManagementImpl.verifyValidatorSignatures(_depositRoot, _signatures));
    }



}

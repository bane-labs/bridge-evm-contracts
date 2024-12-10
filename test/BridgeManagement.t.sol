// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BridgeLib} from "../contracts/library/BridgeLib.sol";
import {SigUtils} from "../contracts/tests/SigUtils.sol";
import {TestBridgeManagement} from "../contracts/tests/TestBridgeManagement.sol";
import {Test} from "../lib/forge-std/src/Test.sol";

contract BridgeManagementImplTest is Test, SigUtils {
    TestBridgeManagement managementProxy;
    address managementProxyAddress;

    SigUtils sigUtils;
    address public owner = 0xBcd4042DE499D14e55001CcbB24a551F3b954096;
    address public funder = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
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

        // Allow constructor to bypass the safety check in deployUUPSProxy.
        // The constructor only contains _disableInitializers() which is safe to bypass.
        Options memory opts;
        opts.unsafeAllow = "constructor";

        // Deploy the management behind a proxy and make sure it's initialized to the latest implementation.
        managementProxyAddress = Upgrades.deployUUPSProxy(
            "TestBridgeManagement.sol",
            abi.encodeCall(
                TestBridgeManagement.initialize,
                (owner, relayer, validatorThreshold, validatorsAddresses, governor, securityGuard, funder)
            ),
            opts
        );
        managementProxy = TestBridgeManagement(managementProxyAddress);
        // Validate that the management proxy has been successfully deployed and initialized to version 2.
        assertEq(managementProxy.getCurrentInitializedVersion(), 2);
    }

    function testSetOwner() public {
        assertEq(managementProxy.owner(), owner);
        vm.prank(funder);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, funder));
        managementProxy.transferOwnership(funder);
        vm.prank(owner);
        managementProxy.transferOwnership(funder);
        assertEq(managementProxy.pendingOwner(), funder);
        vm.prank(funder);
        managementProxy.acceptOwnership();
        assertEq(managementProxy.owner(), funder);
    }

    function testVerifyValidatorSignatures() public view {
        BridgeLib.DepositData memory d = BridgeLib.DepositData({nonce: 1, to: payable(funder), amount: 100});
        bytes32 _depositRoot = getStructHash(d);
        BridgeLib.Signature[] memory _signatures = new BridgeLib.Signature[](5);
        bytes32 ethHash = getSignedHash(_depositRoot);
        for (uint256 i = 0; i < 5; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorsKeys[i], ethHash);
            address recoveredAddr = ecrecover(ethHash, v, r, s);
            _signatures[i] = BridgeLib.Signature(v, r, s);
            assertEq(recoveredAddr, validatorsAddresses[i]);
        }
        assert(managementProxy.verifyValidatorSignatures(_depositRoot, _signatures));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BridgeLib} from "../contracts/library/BridgeLib.sol";
import {SigUtils} from "../contracts/tests/SigUtils.sol";
import {TestBridgeManagement} from "../contracts/tests/TestBridgeManagement.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {IBridgeManagement} from "../contracts/interfaces/IBridgeManagement.sol";
import {BridgeManagementStorage} from "../contracts/management/BridgeManagementStorage.sol";

contract BridgeManagementForgeTest is Test, SigUtils {
    TestBridgeManagement bridgeManagementImpl;
    address managementProxyAddress;

    SigUtils sigUtils;
    address public owner = makeAddr("owner");
    address public funder = makeAddr("funder");
    address public relayer = makeAddr("relayer");
    address public validator1 = makeAddr("validator1");
    address public validator2 = makeAddr("validator2");
    address public validator3 = makeAddr("validator3");
    address public validator4 = makeAddr("validator4");
    address public validator5 = makeAddr("validator5");
    address public validator6 = makeAddr("validator6");
    address public validator7 = makeAddr("validator7");
    address public governor = makeAddr("governor");
    address public securityGuard = makeAddr("securityGuard");

    uint8 public validatorThreshold = 5;
    address[] public validatorsAddresses;

    function setUp() public {
        sigUtils = new SigUtils();

        validatorsAddresses.push(validator1);
        validatorsAddresses.push(validator2);
        validatorsAddresses.push(validator3);
        validatorsAddresses.push(validator4);
        validatorsAddresses.push(validator5);
        validatorsAddresses.push(validator6);
        validatorsAddresses.push(validator7);

        // Allow constructor to bypass the safety check in deployUUPSProxy.
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
        bridgeManagementImpl = TestBridgeManagement(managementProxyAddress);
    }

    // ========== DEPLOYMENT TESTS ==========

    function test_ShouldBeInitializedToCorrectVersion() public view {
        assertEq(bridgeManagementImpl.getCurrentInitializedVersion(), 3);
    }

    function test_ShouldHaveRightRelayer() public view {
        assertEq(bridgeManagementImpl.getRelayer(), relayer);
    }

    function test_ShouldHaveRightValidators() public view {
        address[] memory validators = bridgeManagementImpl.getValidators();
        assertEq(validators.length, 7);
        assertEq(validators[0], validator1);
        assertEq(validators[1], validator2);
        assertEq(validators[2], validator3);
        assertEq(validators[3], validator4);
        assertEq(validators[4], validator5);
        assertEq(validators[5], validator6);
        assertEq(validators[6], validator7);
    }

    function test_ShouldHaveRightOwner() public view {
        assertEq(bridgeManagementImpl.owner(), owner);
    }

    function test_ShouldHaveRightGovernor() public view {
        assertEq(bridgeManagementImpl.getGovernor(), governor);
    }

    function test_ShouldHaveRightSecurityGuard() public view {
        assertEq(bridgeManagementImpl.getSecurityGuard(), securityGuard);
    }

    function test_ShouldHaveRightFunder() public view {
        assertEq(bridgeManagementImpl.getFunder(), funder);
    }

    // ========== BRIDGE ROLE SETTING TESTS ==========

    function test_SetOwner() public {
        // Start ownership transfer
        vm.prank(owner);
        bridgeManagementImpl.transferOwnership(validator2);

        assertEq(bridgeManagementImpl.pendingOwner(), validator2);
        assertEq(bridgeManagementImpl.owner(), owner);

        // Try accepting with wrong account
        vm.prank(validator1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, validator1));
        bridgeManagementImpl.acceptOwnership();

        // Accept ownership with correct account
        vm.prank(validator2);
        bridgeManagementImpl.acceptOwnership();

        assertEq(bridgeManagementImpl.pendingOwner(), address(0));
        assertEq(bridgeManagementImpl.owner(), validator2);
    }

    function test_SetRelayer() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IBridgeManagement.RelayerChange(validator2);
        bridgeManagementImpl.setRelayer(validator2);

        assertEq(bridgeManagementImpl.getRelayer(), validator2);
    }

    function test_SetGovernor() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IBridgeManagement.GovernorChange(validator2);
        bridgeManagementImpl.setGovernor(validator2);

        assertEq(bridgeManagementImpl.getGovernor(), validator2);
    }

    function test_SetSecurityGuard() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IBridgeManagement.SecurityGuardChange(validator2);
        bridgeManagementImpl.setSecurityGuard(validator2);

        assertEq(bridgeManagementImpl.getSecurityGuard(), validator2);
    }

    function test_SetFunder() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IBridgeManagement.FunderChange(validator2);
        bridgeManagementImpl.setFunder(validator2);

        assertEq(bridgeManagementImpl.getFunder(), validator2);
    }

    function test_NonOwnerFailToStartOwnershipTransfer() public {
        vm.prank(validator2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, validator2));
        bridgeManagementImpl.transferOwnership(validator2);
    }

    function test_NonOwnerFailToSetRelayer() public {
        vm.prank(validator2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, validator2));
        bridgeManagementImpl.setRelayer(validator1);
    }

    function test_NonOwnerFailToSetGovernor() public {
        vm.prank(validator2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, validator2));
        bridgeManagementImpl.setGovernor(validator1);
    }

    function test_NonOwnerFailToSetSecurityGuard() public {
        vm.prank(validator2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, validator2));
        bridgeManagementImpl.setSecurityGuard(validator1);
    }

    function test_NonOwnerFailToSetFunder() public {
        vm.prank(validator2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, validator2));
        bridgeManagementImpl.setFunder(validator1);
    }

    // ========== BRIDGE VALIDATOR CHANGES TESTS ==========

    function test_AddValidatorAndIncreaseThreshold() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit IBridgeManagement.ValidatorAdd(owner);
        bridgeManagementImpl.addValidator(owner, true);

        assertEq(bridgeManagementImpl.getValidators().length, 8);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 6);
        assertEq(bridgeManagementImpl.getValidators()[7], owner);
    }

    function test_AddValidatorAndKeepCurrentThreshold() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit IBridgeManagement.ValidatorAdd(owner);
        bridgeManagementImpl.addValidator(owner, false);

        assertEq(bridgeManagementImpl.getValidators().length, 8);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 5);
        assertEq(bridgeManagementImpl.getValidators()[7], owner);
    }

    function test_FailAddingValidatorWithoutAuthorization() public {
        vm.prank(validator1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, validator1));
        bridgeManagementImpl.addValidator(validator1, true);
    }

    function test_FailAddingValidatorThatIsAlreadyValidator() public {
        assertTrue(bridgeManagementImpl.isValidator(validator1));
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(BridgeManagementStorage.AlreadyValidator.selector, validator1));
        bridgeManagementImpl.addValidator(validator1, true);
    }

    function test_FailAddingValidatorWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(BridgeManagementStorage.InvalidAddress.selector);
        bridgeManagementImpl.addValidator(address(0), true);

        vm.prank(owner);
        vm.expectRevert(BridgeManagementStorage.InvalidAddress.selector);
        bridgeManagementImpl.addValidator(address(0), false);
    }

    function test_RemoveValidatorAndDecreaseCurrentThreshold() public {
        assertTrue(bridgeManagementImpl.isValidator(validator1));
        assertEq(bridgeManagementImpl.getValidators().length, 7);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 5);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IBridgeManagement.ValidatorThresholdChange(uint256(4));
        vm.expectEmit(true, false, false, false);
        emit IBridgeManagement.ValidatorRemove(validator1);
        bridgeManagementImpl.removeValidator(validator1, true);

        assertEq(bridgeManagementImpl.getValidators().length, 6);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 4);
    }

    function test_RemoveValidatorAndKeepCurrentThreshold() public {
        assertTrue(bridgeManagementImpl.isValidator(validator1));
        assertEq(bridgeManagementImpl.getValidators().length, 7);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 5);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IBridgeManagement.ValidatorRemove(validator1);
        bridgeManagementImpl.removeValidator(validator1, false);

        assertEq(bridgeManagementImpl.getValidators().length, 6);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 5);
    }

    function test_FailRemovingValidatorWithoutAuthorization() public {
        vm.prank(validator1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, validator1));
        bridgeManagementImpl.removeValidator(validator2, true);
    }

    function test_FailRemovingValidatorIfNotValidator() public {
        assertFalse(bridgeManagementImpl.isValidator(owner));
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(BridgeManagementStorage.NotValidator.selector, owner));
        bridgeManagementImpl.removeValidator(owner, false);
    }

    function test_FailRemovingValidatorAndKeepCurrentThresholdIfThresholdWasEqualToNumberOfValidators() public {
        vm.prank(owner);
        bridgeManagementImpl.removeValidator(validator7, false);
        vm.prank(owner);
        bridgeManagementImpl.removeValidator(validator6, false);

        assertEq(bridgeManagementImpl.getValidators().length, 5);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 5);

        vm.prank(owner);
        vm.expectRevert(BridgeManagementStorage.ValidatorThresholdTooHigh.selector);
        bridgeManagementImpl.removeValidator(validator2, false);

        // The threshold should still be 5 and validator2 should still be a validator
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 5);
        assertTrue(bridgeManagementImpl.isValidator(validator2));

        // Verify that the same removal with a decrease of the threshold works
        vm.prank(owner);
        bridgeManagementImpl.removeValidator(validator2, true);
        assertEq(bridgeManagementImpl.getValidators().length, 4);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 4);
        assertFalse(bridgeManagementImpl.isValidator(validator2));
    }

    function test_FailRemovingValidatorIfThereAreOnlyTwoValidators() public {
        vm.prank(owner);
        bridgeManagementImpl.removeValidator(validator7, false);
        vm.prank(owner);
        bridgeManagementImpl.removeValidator(validator6, false);
        vm.prank(owner);
        bridgeManagementImpl.removeValidator(validator5, true);
        vm.prank(owner);
        bridgeManagementImpl.removeValidator(validator4, true);
        vm.prank(owner);
        bridgeManagementImpl.removeValidator(validator3, true);

        assertEq(bridgeManagementImpl.getValidators().length, 2);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 2);
        assertEq(bridgeManagementImpl.getValidators()[1], validator2);

        vm.prank(owner);
        vm.expectRevert(BridgeManagementStorage.ValidatorThresholdTooLow.selector);
        bridgeManagementImpl.removeValidator(validator2, true);

        vm.prank(owner);
        vm.expectRevert(BridgeManagementStorage.MinValidatorsLimitReached.selector);
        bridgeManagementImpl.removeValidator(validator2, false);

        // The threshold should still be 2 and validator2 should still be a validator
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 2);
        assertTrue(bridgeManagementImpl.isValidator(validator2));
    }

    function test_ReplaceValidator() public {
        address newValidator = owner;
        uint256 index = 3;
        assertEq(bridgeManagementImpl.getValidators().length, 7);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 5);
        assertEq(bridgeManagementImpl.getValidators()[index], validator4);
        assertTrue(bridgeManagementImpl.isValidator(validator4));
        assertFalse(bridgeManagementImpl.isValidator(newValidator));

        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit IBridgeManagement.ValidatorReplace(validator4, newValidator);
        bridgeManagementImpl.replaceValidator(validator4, newValidator);

        assertEq(bridgeManagementImpl.getValidators().length, 7);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 5);
        assertFalse(bridgeManagementImpl.isValidator(validator4));
        assertTrue(bridgeManagementImpl.isValidator(newValidator));
    }

    function test_FailReplacingValidatorWithoutAuthorization() public {
        vm.prank(validator5);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, validator5));
        bridgeManagementImpl.replaceValidator(validator2, owner);
    }

    function test_FailReplacingValidatorWithZeroAddress() public {
        uint256 index = 3;
        assertEq(bridgeManagementImpl.getValidators()[index], validator4);
        assertTrue(bridgeManagementImpl.isValidator(validator4));
        assertFalse(bridgeManagementImpl.isValidator(address(0)));

        vm.prank(owner);
        vm.expectRevert(BridgeManagementStorage.InvalidAddress.selector);
        bridgeManagementImpl.replaceValidator(validator4, address(0));
    }

    function test_FailReplacingValidatorAddressThatIsNoValidator() public {
        address newValidator = owner;
        address oldValidator = relayer;
        assertFalse(bridgeManagementImpl.isValidator(oldValidator));
        assertFalse(bridgeManagementImpl.isValidator(newValidator));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(BridgeManagementStorage.NotValidator.selector, oldValidator));
        bridgeManagementImpl.replaceValidator(oldValidator, newValidator);
    }

    function test_FailReplacingValidatorWithAddressThatIsAlreadyValidator() public {
        address newValidator = validator2;
        uint256 index = 3;
        assertEq(bridgeManagementImpl.getValidators()[index], validator4);
        assertTrue(bridgeManagementImpl.isValidator(validator4));
        assertTrue(bridgeManagementImpl.isValidator(newValidator));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(BridgeManagementStorage.AlreadyValidator.selector, newValidator));
        bridgeManagementImpl.replaceValidator(validator4, newValidator);
    }

    function test_SetValidatorThreshold() public {
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 5);
        assertEq(bridgeManagementImpl.getValidators().length, 7);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IBridgeManagement.ValidatorThresholdChange(4);
        bridgeManagementImpl.setValidatorThreshold(4);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 4);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IBridgeManagement.ValidatorThresholdChange(7);
        bridgeManagementImpl.setValidatorThreshold(7);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 7);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IBridgeManagement.ValidatorThresholdChange(2);
        bridgeManagementImpl.setValidatorThreshold(2);
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 2);
    }

    function test_FailSettingValidatorThresholdWithoutAuthorization() public {
        vm.prank(validator5);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, validator5));
        bridgeManagementImpl.setValidatorThreshold(4);
    }

    function test_FailSettingValidatorThresholdLowerThan2() public {
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 5);
        assertEq(bridgeManagementImpl.getValidators().length, 7);

        vm.prank(owner);
        vm.expectRevert(BridgeManagementStorage.ValidatorThresholdTooLow.selector);
        bridgeManagementImpl.setValidatorThreshold(1);

        vm.prank(owner);
        vm.expectRevert(BridgeManagementStorage.ValidatorThresholdTooLow.selector);
        bridgeManagementImpl.setValidatorThreshold(0);
    }

    function test_FailSettingValidatorThresholdHigherThanNumberOfValidators() public {
        assertEq(bridgeManagementImpl.getValidatorThreshold(), 5);
        assertEq(bridgeManagementImpl.getValidators().length, 7);

        vm.prank(owner);
        vm.expectRevert(BridgeManagementStorage.ValidatorThresholdTooHigh.selector);
        bridgeManagementImpl.setValidatorThreshold(8);
    }
}

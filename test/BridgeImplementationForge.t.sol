// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BridgeStorage} from "../contracts/bridge/BridgeStorage.sol";
import {IBridge} from "../contracts/interfaces/IBridge.sol";
import {IBridgeManagement} from "../contracts/interfaces/IBridgeManagement.sol";
import {INativeBridge} from "../contracts/interfaces/INativeBridge.sol";
import {BridgeLib} from "../contracts/library/BridgeLib.sol";
import {StorageTypes} from "../contracts/library/StorageTypes.sol";
import {SigUtils} from "../contracts/tests/SigUtils.sol";
import {TestBridge} from "../contracts/tests/TestBridge.sol";
import {TestBridgeManagement} from "../contracts/tests/TestBridgeManagement.sol";
import {TestPayableContract} from "../contracts/tests/TestPayableContract.sol";
import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {Options} from "../lib/openzeppelin-foundry-upgrades/src/Options.sol";
import {Upgrades} from "../lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";

contract BridgeImplementationForgeTest is Test, SigUtils {
    TestBridge bridgeContract;
    TestBridgeManagement bridgeManagementContract;
    address bridgeProxyAddress;
    address managementProxyAddress;

    SigUtils sigUtils;
    address public managementOwner = makeAddr("managementOwner");
    address public funder = makeAddr("funder");
    address public relayer = makeAddr("relayer");
    address public validator1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Fixed address from original TypeScript tests
    address public validator2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Fixed address from original TypeScript tests
    address public validator3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Fixed address from original TypeScript tests
    address public validator4 = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // Fixed address from original TypeScript tests
    address public validator5 = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc; // Fixed address from original TypeScript tests
    address public validator6 = 0x976EA74026E726554dB657fA54763abd0C3a0aa9; // Fixed address from original TypeScript tests
    address public validator7 = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955; // Fixed address from original TypeScript tests
    address public governor = makeAddr("governor");
    address public securityGuard = makeAddr("securityGuard");
    address public deployer = makeAddr("deployer");

    uint8 public validatorThreshold = 5;
    address[] public validatorsAddresses;
    uint256[] public validatorsKeys;

    // Use BridgeLib.DepositData instead of custom struct
    BridgeLib.DepositData depositData1 = BridgeLib.DepositData({nonce: 1, to: payable(validator1), amount: 100000000});
    BridgeLib.DepositData depositData2 = BridgeLib.DepositData({nonce: 2, to: payable(validator2), amount: 200000000});
    BridgeLib.DepositData depositData3 = BridgeLib.DepositData({nonce: 3, to: payable(validator3), amount: 300000000});

    function setUp() public {
        sigUtils = new SigUtils();

        validatorsAddresses.push(validator1);
        validatorsAddresses.push(validator2);
        validatorsAddresses.push(validator3);
        validatorsAddresses.push(validator4);
        validatorsAddresses.push(validator5);
        validatorsAddresses.push(validator6);
        validatorsAddresses.push(validator7);

        validatorsKeys.push(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d); // Private key for validator1 (0x70997970C51812dc3A010C7d01b50e0d17dc79C8) - Hardhat account[1]
        validatorsKeys.push(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a); // Private key for validator2 (0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC) - Hardhat account[2]
        validatorsKeys.push(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6); // Private key for validator3 (0x90F79bf6EB2c4f870365E785982E1f101E93b906) - Hardhat account[3]
        validatorsKeys.push(0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a); // Private key for validator4 (0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65) - Hardhat account[4]
        validatorsKeys.push(0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba); // Private key for validator5 (0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc) - Hardhat account[5]
        validatorsKeys.push(0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e); // Private key for validator6 (0x976EA74026E726554dB657fA54763abd0C3a0aa9) - Hardhat account[6]
        validatorsKeys.push(0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6); // Private key for validator7 (0x14dC79964da2C08b23698B3D3cc7Ca32193d9955) - Hardhat account[7]

        // Allow constructor to bypass the safety check in deployUUPSProxy.
        Options memory opts;
        opts.unsafeAllow = "constructor";

        // Deploy the bridge management behind a proxy
        managementProxyAddress = Upgrades.deployUUPSProxy(
            "TestBridgeManagement.sol",
            abi.encodeCall(
                TestBridgeManagement.initialize,
                (managementOwner, relayer, validatorThreshold, validatorsAddresses, governor, securityGuard, funder)
            ),
            opts
        );
        bridgeManagementContract = TestBridgeManagement(managementProxyAddress);

        // Deploy the bridge contract behind a proxy
        bridgeProxyAddress = Upgrades.deployUUPSProxy(
            "TestBridge.sol", abi.encodeCall(TestBridge.initialize, (managementProxyAddress)), opts
        );
        bridgeContract = TestBridge(payable(bridgeProxyAddress));

        // Activate the native bridge
        vm.prank(governor);
        bridgeContract.setNativeBridge(0.1 ether, 1 ether, 10000 ether, 100, 18, 8);
        vm.prank(governor);
        bridgeContract.unpauseNativeBridge();

        // Fund the bridge contract
        vm.deal(funder, 100 ether);
        vm.prank(funder);
        (bool success,) = payable(bridgeContract).call{value: 80 ether}("");
        require(success, "Failed to fund bridge");
    }

    // Helper functions
    function toEthDecimals(uint256 amount) internal pure returns (uint256) {
        return amount * 10 ** 10; // Convert from 8 decimals to 18 decimals
    }

    function toNeoDecimals(uint256 amount) internal pure returns (uint256) {
        return amount / 10 ** 10; // Convert from 18 decimals to 8 decimals
    }

    function hashDepositOrWithdrawal(uint64 nonce, address to, uint256 amount) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(uint256(nonce), to, amount));
    }

    function computeRoot(bytes32 currentRoot, bytes32 depositHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(currentRoot, depositHash));
    }

    function getValidatorSignatures(
        bytes32 root,
        uint256[] memory validatorIndices
    )
        internal
        view
        returns (BridgeLib.Signature[] memory)
    {
        BridgeLib.Signature[] memory signatures = new BridgeLib.Signature[](validatorIndices.length);

        // Create the message hash the same way as the TypeScript tests: keccak256(abi.encodePacked(chainId, root))
        bytes32 messageHash = keccak256(abi.encodePacked(uint256(31337), root));

        // Apply EIP-191 formatting as done by ethers.signMessage()
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        for (uint256 i = 0; i < validatorIndices.length; i++) {
            if (validatorIndices[i] > 0 && validatorIndices[i] <= validatorsKeys.length) {
                uint256 privateKey = validatorsKeys[validatorIndices[i] - 1];
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
                signatures[i] = BridgeLib.Signature({v: v, r: r, s: s});
            }
        }
        return signatures;
    }

    // ========== DEPLOYMENT TESTS ==========

    function test_BridgeShouldBeInitializedToCorrectVersion() public view {
        assertEq(bridgeContract.getCurrentInitializedVersion(), 3);
    }

    function test_BridgeManagementShouldBeInitializedToCorrectVersion() public view {
        assertEq(bridgeManagementContract.getCurrentInitializedVersion(), 3);
    }

    // ========== PARAMETER SETTERS TESTS ==========

    function test_SetWithdrawalFee() public {
        uint256 oldFee = 0.1 ether;
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        assertEq(config.fee, oldFee);

        uint256 newFee = 0.2 ether;
        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit INativeBridge.NativeWithdrawalFeeChange(newFee);
        bridgeContract.setNativeWithdrawalFee(newFee);

        (,,, config) = bridgeContract.nativeBridge();
        assertEq(config.fee, newFee);
    }

    function test_SetMinWithdrawalAmount() public {
        uint256 oldMinAmount = 1 ether;
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        assertEq(config.minAmount, oldMinAmount);

        uint256 newMinAmount = 0.2 ether;
        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit INativeBridge.MinNativeWithdrawalChange(newMinAmount);
        bridgeContract.setMinNativeWithdrawalAmount(newMinAmount);

        (,,, config) = bridgeContract.nativeBridge();
        assertEq(config.minAmount, newMinAmount);
    }

    function test_SetMaxWithdrawalAmount() public {
        uint256 oldMaxAmount = 10000 ether;
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        assertEq(config.maxAmount, oldMaxAmount);

        uint256 newMaxAmount = 5000 ether;
        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit INativeBridge.MaxNativeWithdrawalChange(newMaxAmount);
        bridgeContract.setMaxNativeWithdrawalAmount(newMaxAmount);

        (,,, config) = bridgeContract.nativeBridge();
        assertEq(config.maxAmount, newMaxAmount);

        uint256 newMaxAmount2 = 10000 ether;
        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit INativeBridge.MaxNativeWithdrawalChange(newMaxAmount2);
        bridgeContract.setMaxNativeWithdrawalAmount(newMaxAmount2);

        (,,, config) = bridgeContract.nativeBridge();
        assertEq(config.maxAmount, newMaxAmount2);
    }

    function test_SetInvalidMinAndMaxWithdrawalAmounts() public {
        uint256 fraction = 0.00000001 ether;
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 minWithdrawalAmount = config.minAmount;
        uint256 lowerThanMinWithdrawalAmount = minWithdrawalAmount - fraction;
        uint256 maxWithdrawalAmount = config.maxAmount;
        uint256 higherThanMaxWithdrawalAmount = maxWithdrawalAmount + fraction;

        // min amount must not be greater than max amount
        vm.prank(governor);
        vm.expectRevert();
        bridgeContract.setMinNativeWithdrawalAmount(higherThanMaxWithdrawalAmount);

        // min amount must not be greater than or equal to max amount
        vm.prank(governor);
        vm.expectRevert();
        bridgeContract.setMinNativeWithdrawalAmount(maxWithdrawalAmount);

        // min amount must have maximal 8 non-zero digits
        vm.prank(governor);
        vm.expectRevert();
        bridgeContract.setMinNativeWithdrawalAmount(1000000000);

        // max amount must not be less than min amount
        vm.prank(governor);
        vm.expectRevert();
        bridgeContract.setMaxNativeWithdrawalAmount(lowerThanMinWithdrawalAmount);

        // max amount must not be less than or equal to min amount
        vm.prank(governor);
        vm.expectRevert();
        bridgeContract.setMaxNativeWithdrawalAmount(minWithdrawalAmount);

        // max amount must have maximal 8 non-zero digits
        vm.prank(governor);
        vm.expectRevert();
        bridgeContract.setMaxNativeWithdrawalAmount(1000000000);
    }

    function test_SetMaxDepositsPerDistribution() public {
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 maxDepositsPerDistribution = config.maxDeposits;
        uint256 newMaxDeposits = 10;
        assertNotEq(maxDepositsPerDistribution, newMaxDeposits);

        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit INativeBridge.MaxNativeDepositsChange(newMaxDeposits);
        bridgeContract.setMaxNativeDeposits(newMaxDeposits);

        (,,, config) = bridgeContract.nativeBridge();
        assertEq(config.maxDeposits, newMaxDeposits);
    }

    function test_FailSettingMaxDepositsPerDistributionToZero() public {
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 maxDepositsPerDistribution = config.maxDeposits;
        assertGt(maxDepositsPerDistribution, 0);

        vm.prank(governor);
        vm.expectRevert();
        bridgeContract.setMaxNativeDeposits(0);
    }

    // ========== FUNDING THE BRIDGE TESTS ==========

    function test_FundTheBridgeContract() public {
        uint256 bridgeContractBalance = address(bridgeContract).balance;
        assertEq(bridgeContractBalance, 80 ether);

        uint256 fundAmount = 20 ether;
        vm.deal(funder, fundAmount);

        uint256 funderBalanceBefore = funder.balance;
        uint256 bridgeBalanceBefore = address(bridgeContract).balance;

        vm.prank(funder);
        vm.expectEmit(true, false, false, false);
        emit IBridge.Fund(fundAmount);
        (bool success,) = payable(bridgeContract).call{value: fundAmount}("");
        require(success, "Fund failed");

        assertEq(funder.balance, funderBalanceBefore - fundAmount);
        assertEq(address(bridgeContract).balance, bridgeBalanceBefore + fundAmount);
    }

    function test_NotFunderFailsToFundTheBridgeContract() public {
        uint256 bridgeContractBalance = address(bridgeContract).balance;
        assertEq(bridgeContractBalance, 80 ether);

        vm.deal(governor, 20 ether);
        vm.prank(governor);
        vm.expectRevert("not funder");
        (bool b,) = payable(bridgeContract).call{value: 20 ether}("");
    }

    function test_CanFundAfterSetAsFunder() public {
        uint256 bridgeContractBalance = address(bridgeContract).balance;
        assertEq(bridgeContractBalance, 80 ether);

        vm.deal(validator1, 20 ether);
        uint256 fundAmount = 10 ether;

        // Try to fund before being set as funder - should fail
        vm.prank(validator1);
        vm.expectRevert("not funder");
        (bool success,) = payable(bridgeContract).call{value: fundAmount}("");
        // No need for require(!success) after expectRevert - if the revert happens, test passes

        address funderBefore = bridgeManagementContract.getFunder();
        assertNotEq(funderBefore, validator1);

        // Set validator1 as funder
        vm.prank(managementOwner);
        vm.expectEmit(true, false, false, false);
        emit IBridgeManagement.FunderChange(validator1);
        bridgeManagementContract.setFunder(validator1);

        assertEq(bridgeManagementContract.getFunder(), validator1);

        // Now funding should work
        uint256 validator1BalanceBefore = validator1.balance;
        uint256 bridgeBalanceBefore = address(bridgeContract).balance;

        vm.prank(validator1);
        vm.expectEmit(true, false, false, false);
        emit IBridge.Fund(fundAmount);
        (success,) = payable(bridgeContract).call{value: fundAmount}("");
        require(success, "Fund should succeed");

        assertEq(validator1.balance, validator1BalanceBefore - fundAmount);
        assertEq(address(bridgeContract).balance, bridgeBalanceBefore + fundAmount);
    }

    // ========== DEPOSIT TESTS ==========

    function test_DepositTheFirstNonce() public {
        uint64 nonce = 1;
        address to = validator1; // Use the same fixed address as the original TypeScript test
        uint256 amount = 100000000;

        bytes32 hashDepositData1 = hashDepositOrWithdrawal(nonce, to, amount);
        // Raw deposit hash and root from deposit computed on Neo N3 bridge contract
        assertEq(hashDepositData1, 0x7ed36781b8366a590ce568db6712d377c031b9f1a21c44cda2493182b0ff92e5);
        bytes32 root1 = computeRoot(bytes32(0), hashDepositData1);
        assertEq(root1, 0x70789f5bdb108a6b6dc7d7aa0d31649ab5fa980bbbfd1868eb17821b1f61e0ac);

        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(root1, validatorIndices);

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = BridgeLib.DepositData({nonce: nonce, to: payable(to), amount: amount});

        uint256 bridgeBalanceBefore = address(bridgeContract).balance;
        uint256 recipientBalanceBefore = to.balance;

        vm.prank(relayer);
        bridgeContract.depositNative(root1, signatures, deposits);

        assertEq(address(bridgeContract).balance, bridgeBalanceBefore - toEthDecimals(amount));
        assertEq(to.balance, recipientBalanceBefore + toEthDecimals(amount));
    }

    function test_DepositWithSignaturesOutOfAnyOrder() public {
        uint64 nonce = 1;
        address to = makeAddr("recipient");
        uint256 amount = 100000000;

        bytes32 hashDepositData1 = hashDepositOrWithdrawal(nonce, to, amount);
        bytes32 root1 = computeRoot(bytes32(0), hashDepositData1);

        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 5;
        validatorIndices[1] = 2;
        validatorIndices[2] = 4;
        validatorIndices[3] = 1;
        validatorIndices[4] = 3;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(root1, validatorIndices);

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = BridgeLib.DepositData({nonce: nonce, to: payable(to), amount: amount});

        uint256 bridgeBalanceBefore = address(bridgeContract).balance;
        uint256 recipientBalanceBefore = to.balance;

        vm.prank(relayer);
        bridgeContract.depositNative(root1, signatures, deposits);

        assertEq(address(bridgeContract).balance, bridgeBalanceBefore - toEthDecimals(amount));
        assertEq(to.balance, recipientBalanceBefore + toEthDecimals(amount));
    }

    function test_DepositWithMultipleContinuousNonce() public {
        address to1 = validator1; // Use the same fixed address as the original TypeScript test (0x70997970C51812dc3A010C7d01b50e0d17dc79C8)
        uint256 amount1 = 100000000;
        address to2 = 0x89FC6B042b146F373CeC4CA4A1b112697763360f; // Use the same fixed address as the original TypeScript test
        uint256 amount2 = 100000000;

        bytes32 hashDepositData1 = hashDepositOrWithdrawal(1, to1, amount1);
        assertEq(hashDepositData1, 0x7ed36781b8366a590ce568db6712d377c031b9f1a21c44cda2493182b0ff92e5);
        bytes32 hashDepositData2 = hashDepositOrWithdrawal(2, to2, amount2);
        assertEq(hashDepositData2, 0xcba84a7e0f42d61e4510f0b13ae53c138cb1864b97f598d273c9fb3a9fe8d51a);
        bytes32 root1 = computeRoot(bytes32(0), hashDepositData1);
        assertEq(root1, 0x70789f5bdb108a6b6dc7d7aa0d31649ab5fa980bbbfd1868eb17821b1f61e0ac);
        bytes32 newRoot = computeRoot(root1, hashDepositData2);
        assertEq(newRoot, 0xa15d5e4d94b19c1c4c8aa07157bb03a121e5b886c76e5ec7cecab139eb342236);

        BridgeLib.Signature[] memory signatures;
        {
            uint256[] memory validatorIndices = new uint256[](5);
            validatorIndices[0] = 1;
            validatorIndices[1] = 2;
            validatorIndices[2] = 3;
            validatorIndices[3] = 4;
            validatorIndices[4] = 5;
            signatures = getValidatorSignatures(newRoot, validatorIndices);
        }

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](2);
        deposits[0] = BridgeLib.DepositData({nonce: 1, to: payable(to1), amount: amount1});
        deposits[1] = BridgeLib.DepositData({nonce: 2, to: payable(to2), amount: amount2});

        uint256 bridgeBalanceBefore = address(bridgeContract).balance;
        uint256 recipient1BalanceBefore = to1.balance;
        uint256 recipient2BalanceBefore = to2.balance;

        vm.prank(relayer);
        vm.expectEmit(true, true, false, false);
        emit INativeBridge.NativeDepositRootUpdate(uint256(2), newRoot);
        vm.expectEmit(true, true, true, false);
        emit INativeBridge.NativeDeposit(uint256(1), to1, amount1);
        vm.expectEmit(true, true, true, false);
        emit INativeBridge.NativeDeposit(uint256(2), to2, amount2);
        bridgeContract.depositNative(newRoot, signatures, deposits);

        assertEq(address(bridgeContract).balance, bridgeBalanceBefore - toEthDecimals(amount1 + amount2));
        assertEq(to1.balance, recipient1BalanceBefore + toEthDecimals(amount1));
        assertEq(to2.balance, recipient2BalanceBefore + toEthDecimals(amount2));

        (, StorageTypes.State memory depositState,,) = bridgeContract.nativeBridge();
        assertEq(depositState.nonce, 2);
        assertEq(depositState.root, newRoot);
    }

    function test_ShouldRevertWithNoDeposits() public {
        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](0);
        BridgeLib.Signature[] memory signatures = new BridgeLib.Signature[](0);

        vm.prank(relayer);
        vm.expectRevert();
        bridgeContract.depositNative(bytes32(0), signatures, deposits);
    }

    function test_ShouldRevertWhenProvidingTooManyDepositsInSingleTransaction() public {
        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](101);
        bytes32 hashResult = bytes32(0);

        for (uint256 i = 0; i < 101; i++) {
            deposits[i] = BridgeLib.DepositData({nonce: uint64(i + 1), to: payable(relayer), amount: 100000000});
            hashResult = computeRoot(hashResult, hashDepositOrWithdrawal(uint64(i + 1), relayer, 100000000));
        }

        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(hashResult, validatorIndices);

        vm.prank(relayer);
        vm.expectRevert(BridgeStorage.InvalidDepositsLength.selector);
        bridgeContract.depositNative(hashResult, signatures, deposits);
    }

    function test_ShouldRevertWithWrongFirstNonce() public {
        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = depositData2; // Starting with nonce 2 instead of 1
        BridgeLib.Signature[] memory signatures = new BridgeLib.Signature[](0);

        vm.prank(relayer);
        vm.expectRevert();
        bridgeContract.depositNative(bytes32(0), signatures, deposits);
    }

    function test_ShouldRevertWhenNonceIsNotSubsequent() public {
        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](2);
        deposits[0] = depositData1; // nonce 1
        deposits[1] = depositData3; // nonce 3, skipping 2
        BridgeLib.Signature[] memory signatures = new BridgeLib.Signature[](0);

        vm.prank(relayer);
        vm.expectRevert();
        bridgeContract.depositNative(bytes32(0), signatures, deposits);
    }

    function test_ShouldRevertWhenSignatureLengthLessThan5() public {
        bytes32 hashDepositData1 =
            hashDepositOrWithdrawal(uint64(depositData1.nonce), depositData1.to, depositData1.amount);
        bytes32 root1 = computeRoot(bytes32(0), hashDepositData1);

        BridgeLib.Signature[] memory signatures;
        {
            uint256[] memory validatorIndices = new uint256[](4);
            validatorIndices[0] = 1;
            validatorIndices[1] = 2;
            validatorIndices[2] = 3;
            validatorIndices[3] = 4;
            signatures = getValidatorSignatures(root1, validatorIndices);
        }

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = depositData1;

        vm.prank(relayer);
        vm.expectRevert();
        bridgeContract.depositNative(root1, signatures, deposits);
    }

    // ========== WITHDRAW TESTS ==========

    function test_WithdrawOnlyOnce() public {
        uint256 withdrawalAmount = 10 ether;
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 withdrawalFee = config.fee;

        uint256 bridgeBalanceBefore = address(bridgeContract).balance;

        vm.deal(relayer, withdrawalAmount + withdrawalFee);
        vm.prank(relayer);
        vm.expectEmit(true, true, true, true);
        emit INativeBridge.NativeWithdrawal(
            1,
            relayer,
            toNeoDecimals(withdrawalAmount),
            relayer,
            hashDepositOrWithdrawal(1, relayer, toNeoDecimals(withdrawalAmount)),
            computeRoot(bytes32(0), hashDepositOrWithdrawal(1, relayer, toNeoDecimals(withdrawalAmount)))
        );
        bridgeContract.withdrawNative{value: withdrawalAmount + withdrawalFee}(relayer, withdrawalFee);

        (,, StorageTypes.State memory withdrawalState,) = bridgeContract.nativeBridge();
        assertEq(withdrawalState.nonce, 1);
        assertEq(address(bridgeContract).balance, bridgeBalanceBefore + withdrawalAmount + withdrawalFee);
        assertEq(relayer.balance, 0);
    }

    function test_WithdrawMultipleTimes() public {
        uint256 withdrawalAmount1 = 1 ether;
        uint256 withdrawalAmount2 = 2 ether;
        uint256 withdrawalFee;
        {
            (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
            withdrawalFee = config.fee;

            vm.deal(relayer, withdrawalAmount1 + withdrawalAmount2 + 2 * withdrawalFee);

            // First withdrawal
            vm.prank(relayer);
            bridgeContract.withdrawNative{value: withdrawalAmount1 + withdrawalFee}(relayer, withdrawalFee);
        }
        // Second withdrawal
        vm.prank(relayer);
        vm.expectEmit(true, true, true, true);
        emit INativeBridge.NativeWithdrawal(
            2,
            validator1,
            toNeoDecimals(withdrawalAmount2),
            relayer,
            hashDepositOrWithdrawal(2, validator1, toNeoDecimals(withdrawalAmount2)),
            computeRoot(
                computeRoot(bytes32(0), hashDepositOrWithdrawal(1, relayer, toNeoDecimals(withdrawalAmount1))),
                hashDepositOrWithdrawal(2, validator1, toNeoDecimals(withdrawalAmount2))
            )
        );
        bridgeContract.withdrawNative{value: withdrawalAmount2 + withdrawalFee}(validator1, withdrawalFee);

        (,, StorageTypes.State memory withdrawalState,) = bridgeContract.nativeBridge();
        assertEq(withdrawalState.nonce, 2);
    }

    function test_WithdrawWithAmountEdgeCase() public {
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 minWithdrawalAmount = config.minAmount;
        uint256 withdrawalFee = config.fee;
        uint256 minWithdrawalAmountWithFee = minWithdrawalAmount + withdrawalFee;

        uint256 bridgeBalanceBefore = address(bridgeContract).balance;

        vm.deal(relayer, minWithdrawalAmountWithFee);
        vm.prank(relayer);
        bridgeContract.withdrawNative{value: minWithdrawalAmountWithFee}(relayer, withdrawalFee);

        (,, StorageTypes.State memory withdrawalState,) = bridgeContract.nativeBridge();
        assertEq(withdrawalState.nonce, 1);
        assertEq(address(bridgeContract).balance, bridgeBalanceBefore + minWithdrawalAmountWithFee);
        assertEq(relayer.balance, 0);
    }

    function test_WithdrawWithWrongAmount() public {
        uint256 invalidAmount = 2.000000001 ether;
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 withdrawalFee = config.fee;

        vm.deal(relayer, invalidAmount);
        vm.prank(relayer);
        vm.expectRevert();
        bridgeContract.withdrawNative{value: invalidAmount}(relayer, withdrawalFee);
    }

    function test_WithdrawIsTooLow() public {
        uint256 minFraction = 0.00000001 ether;
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 minWithdrawalAmount = config.minAmount;
        uint256 withdrawalFee = config.fee;
        uint256 tooLowWithdrawalAmount = minWithdrawalAmount + withdrawalFee - minFraction;

        vm.deal(relayer, tooLowWithdrawalAmount);
        vm.prank(relayer);
        vm.expectRevert();
        bridgeContract.withdrawNative{value: tooLowWithdrawalAmount}(relayer, withdrawalFee);
    }

    function test_WithdrawIsTooHigh() public {
        uint256 minFraction = 0.00000001 ether;
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 maxWithdrawalAmount = config.maxAmount;
        uint256 withdrawalFee = config.fee;
        uint256 tooHighWithdrawalAmount = maxWithdrawalAmount + withdrawalFee + minFraction;

        vm.deal(validator7, tooHighWithdrawalAmount);
        vm.prank(validator7);
        vm.expectRevert();
        bridgeContract.withdrawNative{value: tooHighWithdrawalAmount}(validator6, withdrawalFee);
    }

    // ========== CLAIM TESTS ==========

    function test_ClaimSuccessfulForEOAAccount() public {
        uint256 depositAmount = 8000000001;
        BridgeLib.DepositData memory largeDeposit =
            BridgeLib.DepositData({nonce: 1, to: payable(validator1), amount: depositAmount});

        // This deposit should be too large to execute immediately
        assertTrue(address(bridgeContract).balance < toEthDecimals(depositAmount));

        bytes32 hashDepositData1 =
            hashDepositOrWithdrawal(uint64(largeDeposit.nonce), largeDeposit.to, largeDeposit.amount);
        bytes32 newRoot = computeRoot(bytes32(0), hashDepositData1);

        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(newRoot, validatorIndices);

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = largeDeposit;

        // Deposit should create a claimable entry
        vm.prank(relayer);
        vm.expectEmit(true, true, true, false);
        emit INativeBridge.NativeClaimable(largeDeposit.nonce, largeDeposit.to, largeDeposit.amount);
        bridgeContract.depositNative(newRoot, signatures, deposits);

        // Check claimable state
        (address claimableTo, uint256 claimableAmount) = bridgeContract.claimableNative(largeDeposit.nonce);
        assertEq(claimableTo, largeDeposit.to);
        assertEq(claimableAmount, largeDeposit.amount);

        // Fund the bridge to make claim possible
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 withdrawalFee = config.fee;
        vm.deal(relayer, 10 ether + withdrawalFee);
        vm.prank(relayer);
        bridgeContract.withdrawNative{value: 10 ether + withdrawalFee}(relayer, withdrawalFee);

        // Now claim should work
        uint256 validator1BalanceBefore = validator1.balance;
        uint256 bridgeBalanceBefore = address(bridgeContract).balance;

        vm.prank(validator1);
        vm.expectEmit(true, true, true, false);
        emit INativeBridge.NativeClaim(largeDeposit.nonce, largeDeposit.to, largeDeposit.amount);
        bridgeContract.claimNative(largeDeposit.nonce);

        // Check final state
        (claimableTo, claimableAmount) = bridgeContract.claimableNative(largeDeposit.nonce);
        assertEq(claimableTo, address(0));
        assertEq(claimableAmount, 0);
        assertEq(validator1.balance, validator1BalanceBefore + toEthDecimals(largeDeposit.amount));
        assertEq(address(bridgeContract).balance, bridgeBalanceBefore - toEthDecimals(largeDeposit.amount));
    }

    function test_ClaimSuccessfulForContractAccount() public {
        TestPayableContract testPayableContract = new TestPayableContract();

        BridgeLib.DepositData memory contractDeposit =
            BridgeLib.DepositData({nonce: 1, to: payable(address(testPayableContract)), amount: 10000000});
        bytes32 hashDepositData1 =
            hashDepositOrWithdrawal(uint64(contractDeposit.nonce), contractDeposit.to, contractDeposit.amount);
        bytes32 newRoot = computeRoot(bytes32(0), hashDepositData1);

        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(newRoot, validatorIndices);

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = contractDeposit;

        vm.prank(relayer);
        vm.expectEmit(true, true, true, false);
        emit INativeBridge.NativeClaimable(contractDeposit.nonce, contractDeposit.to, contractDeposit.amount);
        bridgeContract.depositNative(newRoot, signatures, deposits);

        // Claim the deposit
        uint256 contractBalanceBefore = address(testPayableContract).balance;
        uint256 bridgeBalanceBefore = address(bridgeContract).balance;

        vm.prank(validator1);
        vm.expectEmit(true, true, true, false);
        emit INativeBridge.NativeClaim(contractDeposit.nonce, contractDeposit.to, contractDeposit.amount);
        bridgeContract.claimNative(contractDeposit.nonce);

        assertEq(address(testPayableContract).balance, contractBalanceBefore + toEthDecimals(contractDeposit.amount));
        assertEq(address(bridgeContract).balance, bridgeBalanceBefore - toEthDecimals(contractDeposit.amount));

        // Trying to claim again should fail
        vm.prank(relayer);
        vm.expectRevert(BridgeStorage.NonexistentClaimable.selector);
        bridgeContract.claimNative(contractDeposit.nonce);
    }

    function test_FailToClaimDueToContractNotPayable() public {
        // Using the bridge contract itself as non-payable recipient
        BridgeLib.DepositData memory contractDeposit =
            BridgeLib.DepositData({nonce: 1, to: payable(bridgeContract), amount: 100000000});
        bytes32 hashDepositData1 =
            hashDepositOrWithdrawal(uint64(contractDeposit.nonce), contractDeposit.to, contractDeposit.amount);
        bytes32 newRoot = computeRoot(bytes32(0), hashDepositData1);

        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(newRoot, validatorIndices);

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = contractDeposit;

        vm.prank(relayer);
        vm.expectEmit(true, true, true, false);
        emit INativeBridge.NativeClaimable(contractDeposit.nonce, contractDeposit.to, contractDeposit.amount);
        bridgeContract.depositNative(newRoot, signatures, deposits);

        vm.prank(validator1);
        vm.expectRevert(BridgeStorage.TransferFailed.selector);
        bridgeContract.claimNative(contractDeposit.nonce);
    }

    function test_FailToClaimForNotExistedNonceInClaimTable() public {
        vm.prank(validator1);
        vm.expectRevert(BridgeStorage.NonexistentClaimable.selector);
        bridgeContract.claimNative(3);
    }

    // ========== PAUSING TESTS ==========

    function test_PauseWithGovernorOrSecurityGuardAndUnpauseWithGovernor() public {
        vm.prank(securityGuard);
        bridgeContract.pauseBridge();
        assertTrue(bridgeContract.bridgePaused());

        // Try to unlock with non-governor - should fail
        vm.prank(validator1);
        vm.expectRevert("not governor");
        bridgeContract.unpauseBridge();

        // Unlock with governor
        vm.prank(governor);
        bridgeContract.unpauseBridge();
        assertFalse(bridgeContract.bridgePaused());
    }

    function test_CanOnlyPauseIfGovernorOrSecurityGuard() public {
        vm.prank(validator1);
        vm.expectRevert(BridgeStorage.NoAuthorization.selector);
        bridgeContract.pauseBridge();
        assertFalse(bridgeContract.bridgePaused());

        vm.prank(governor);
        bridgeContract.pauseBridge();
        assertTrue(bridgeContract.bridgePaused());

        vm.prank(governor);
        bridgeContract.unpauseBridge();
        assertFalse(bridgeContract.bridgePaused());

        vm.prank(securityGuard);
        bridgeContract.pauseBridge();
        assertTrue(bridgeContract.bridgePaused());

        vm.prank(governor);
        bridgeContract.unpauseBridge();
    }

    function test_CannotUnpauseContractIfAlreadyUnpaused() public {
        vm.prank(governor);
        vm.expectRevert(BridgeStorage.BridgeNotPaused.selector);
        bridgeContract.unpauseBridge();
    }

    function test_CannotPauseContractIfPausedAlready() public {
        vm.prank(securityGuard);
        vm.expectEmit(false, false, false, false);
        emit IBridge.BridgePause();
        bridgeContract.pauseBridge();

        vm.prank(securityGuard);
        vm.expectRevert(BridgeStorage.BridgePaused.selector);
        bridgeContract.pauseBridge();
    }

    function test_CannotDepositClaimOrWithdrawNativeCoinIfContractIsPaused() public {
        vm.prank(securityGuard);
        bridgeContract.pauseBridge();

        // Test deposit fails
        bytes32 hashDepositData1 =
            hashDepositOrWithdrawal(uint64(depositData1.nonce), depositData1.to, depositData1.amount);
        bytes32 root1 = computeRoot(bytes32(0), hashDepositData1);
        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(root1, validatorIndices);
        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = depositData1;

        vm.prank(relayer);
        vm.expectRevert(BridgeStorage.BridgePaused.selector);
        bridgeContract.depositNative(root1, signatures, deposits);

        // Test claim fails
        vm.prank(relayer);
        vm.expectRevert(BridgeStorage.BridgePaused.selector);
        bridgeContract.claimNative(depositData1.nonce);

        // Test withdraw fails
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 withdrawalFee = config.fee;
        vm.deal(relayer, 1 ether + withdrawalFee);
        vm.prank(relayer);
        vm.expectRevert(BridgeStorage.BridgePaused.selector);
        bridgeContract.withdrawNative{value: 1 ether + withdrawalFee}(relayer, withdrawalFee);

        // Test pause again fails
        vm.prank(securityGuard);
        vm.expectRevert(BridgeStorage.BridgePaused.selector);
        bridgeContract.pauseBridge();
    }

    // ========== WITHDRAWAL PAUSING TESTS ==========

    function test_GovernorCanPauseWithdrawals() public {
        assertFalse(bridgeContract.withdrawalsPaused());
        vm.prank(governor);
        bridgeContract.pauseWithdrawals();
        assertTrue(bridgeContract.withdrawalsPaused());
    }

    function test_GovernorCanUnpauseWithdrawals() public {
        vm.prank(governor);
        bridgeContract.pauseWithdrawals();
        assertTrue(bridgeContract.withdrawalsPaused());

        vm.prank(governor);
        bridgeContract.unpauseWithdrawals();
        assertFalse(bridgeContract.withdrawalsPaused());
    }

    function test_NonGovernorCannotPauseWithdrawals() public {
        assertFalse(bridgeContract.withdrawalsPaused());

        vm.prank(relayer);
        vm.expectRevert("not governor");
        bridgeContract.pauseWithdrawals();

        vm.prank(securityGuard);
        vm.expectRevert("not governor");
        bridgeContract.pauseWithdrawals();
    }

    function test_NonGovernorCannotUnpauseWithdrawals() public {
        vm.prank(governor);
        bridgeContract.pauseWithdrawals();
        assertTrue(bridgeContract.withdrawalsPaused());

        vm.prank(relayer);
        vm.expectRevert("not governor");
        bridgeContract.unpauseWithdrawals();

        vm.prank(securityGuard);
        vm.expectRevert("not governor");
        bridgeContract.unpauseWithdrawals();
    }

    function test_NativeCoinWithdrawalsAreRejectedWhileWithdrawalsArePaused() public {
        vm.prank(governor);
        bridgeContract.pauseWithdrawals();
        assertTrue(bridgeContract.withdrawalsPaused());

        uint256 withdrawalAmount = 10 ether;
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 withdrawalFee = config.fee;

        vm.deal(relayer, withdrawalAmount + withdrawalFee);
        vm.prank(relayer);
        vm.expectRevert(BridgeStorage.WithdrawalsPaused.selector);
        bridgeContract.withdrawNative{value: withdrawalAmount + withdrawalFee}(relayer, withdrawalFee);
    }

    function test_NativeCoinDepositsAreAllowedWhileWithdrawalsArePaused() public {
        vm.prank(governor);
        bridgeContract.pauseWithdrawals();
        assertTrue(bridgeContract.withdrawalsPaused());

        uint64 nonce = 1;
        address to = makeAddr("recipient");
        uint256 amount = 100000000;

        bytes32 hashDepositData1 = hashDepositOrWithdrawal(nonce, to, amount);
        bytes32 root1 = computeRoot(bytes32(0), hashDepositData1);

        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(root1, validatorIndices);

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = BridgeLib.DepositData({nonce: nonce, to: payable(to), amount: amount});

        uint256 bridgeBalanceBefore = address(bridgeContract).balance;
        uint256 recipientBalanceBefore = to.balance;

        vm.prank(relayer);
        bridgeContract.depositNative(root1, signatures, deposits);

        assertEq(address(bridgeContract).balance, bridgeBalanceBefore - toEthDecimals(amount));
        assertEq(to.balance, recipientBalanceBefore + toEthDecimals(amount));
    }

    // ========== NEWLY MIGRATED TESTS ==========

    function test_DepositWithMultipleTimesWithDifferentNonceArray() public {
        // First deposit with nonce 1
        bytes32 hashDepositData1 =
            hashDepositOrWithdrawal(uint64(depositData1.nonce), depositData1.to, depositData1.amount);
        bytes32 root1 = computeRoot(bytes32(0), hashDepositData1);

        uint256[] memory validatorIndices1 = new uint256[](5);
        validatorIndices1[0] = 1;
        validatorIndices1[1] = 2;
        validatorIndices1[2] = 3;
        validatorIndices1[3] = 4;
        validatorIndices1[4] = 5;
        BridgeLib.Signature[] memory signatures1 = getValidatorSignatures(root1, validatorIndices1);

        BridgeLib.DepositData[] memory deposits1 = new BridgeLib.DepositData[](1);
        deposits1[0] = depositData1;

        vm.prank(relayer);
        bridgeContract.depositNative(root1, signatures1, deposits1);

        // Second deposit with nonces 2 and 3
        bytes32 hashDepositData2 =
            hashDepositOrWithdrawal(uint64(depositData2.nonce), depositData2.to, depositData2.amount);
        bytes32 hash12 = computeRoot(root1, hashDepositData2);
        bytes32 hashDepositData3 =
            hashDepositOrWithdrawal(uint64(depositData3.nonce), depositData3.to, depositData3.amount);
        bytes32 hash123 = computeRoot(hash12, hashDepositData3);

        uint256[] memory validatorIndices2 = new uint256[](5);
        validatorIndices2[0] = 1;
        validatorIndices2[1] = 2;
        validatorIndices2[2] = 3;
        validatorIndices2[3] = 4;
        validatorIndices2[4] = 5;
        BridgeLib.Signature[] memory signatures2 = getValidatorSignatures(hash123, validatorIndices2);

        BridgeLib.DepositData[] memory deposits2 = new BridgeLib.DepositData[](2);
        deposits2[0] = depositData2;
        deposits2[1] = depositData3;

        uint256 bridgeBalanceBefore = address(bridgeContract).balance;
        uint256 recipient2BalanceBefore = depositData2.to.balance;
        uint256 recipient3BalanceBefore = depositData3.to.balance;

        vm.prank(relayer);
        vm.expectEmit(true, true, false, false);
        emit INativeBridge.NativeDepositRootUpdate(depositData3.nonce, hash123);
        vm.expectEmit(true, true, false, false);
        emit INativeBridge.NativeDeposit(depositData2.nonce, depositData2.to, depositData2.amount);
        vm.expectEmit(true, true, false, false);
        emit INativeBridge.NativeDeposit(depositData3.nonce, depositData3.to, depositData3.amount);
        bridgeContract.depositNative(hash123, signatures2, deposits2);

        assertEq(
            address(bridgeContract).balance,
            bridgeBalanceBefore - toEthDecimals(depositData2.amount + depositData3.amount)
        );
        assertEq(depositData2.to.balance, recipient2BalanceBefore + toEthDecimals(depositData2.amount));
        assertEq(depositData3.to.balance, recipient3BalanceBefore + toEthDecimals(depositData3.amount));

        (, StorageTypes.State memory depositState,,) = bridgeContract.nativeBridge();
        assertEq(depositState.nonce, depositData3.nonce);
        assertEq(depositState.root, hash123);
    }

    function test_BridgeTwoDepositsWithInsufficientFundsForExecutingTheFirstDeposit() public {
        uint256 bridgeContractBalance = address(bridgeContract).balance;

        BridgeLib.DepositData memory largeDeposit =
            BridgeLib.DepositData({nonce: 1, to: payable(validator1), amount: 10000000001}); // Large amount > bridge balance
        assertTrue(toEthDecimals(largeDeposit.amount) > bridgeContractBalance);
        assertTrue(toEthDecimals(depositData2.amount) <= bridgeContractBalance);

        bytes32 hashDepositData1 =
            hashDepositOrWithdrawal(uint64(largeDeposit.nonce), largeDeposit.to, largeDeposit.amount);
        bytes32 hashDepositData2 =
            hashDepositOrWithdrawal(uint64(depositData2.nonce), depositData2.to, depositData2.amount);
        bytes32 root1 = computeRoot(bytes32(0), hashDepositData1);
        bytes32 newRoot = computeRoot(root1, hashDepositData2);

        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(newRoot, validatorIndices);

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](2);
        deposits[0] = largeDeposit;
        deposits[1] = depositData2;

        uint256 bridgeBalanceBefore = address(bridgeContract).balance;
        uint256 largeDepositRecipientBalanceBefore = largeDeposit.to.balance;
        uint256 deposit2RecipientBalanceBefore = depositData2.to.balance;

        vm.prank(relayer);
        vm.expectEmit(true, true, true, false);
        emit INativeBridge.NativeClaimable(largeDeposit.nonce, largeDeposit.to, largeDeposit.amount);
        bridgeContract.depositNative(newRoot, signatures, deposits);

        // Check the balance changes - only deposit2 should be paid out
        assertEq(address(bridgeContract).balance, bridgeBalanceBefore - toEthDecimals(depositData2.amount));
        assertEq(largeDeposit.to.balance, largeDepositRecipientBalanceBefore); // No change
        assertEq(depositData2.to.balance, deposit2RecipientBalanceBefore + toEthDecimals(depositData2.amount));

        (, StorageTypes.State memory depositState,,) = bridgeContract.nativeBridge();
        assertEq(depositState.nonce, depositData2.nonce);
        assertEq(depositState.root, newRoot);

        // Check claimable state
        (address claimableTo1, uint256 claimableAmount1) = bridgeContract.claimableNative(largeDeposit.nonce);
        assertEq(claimableTo1, largeDeposit.to);
        assertEq(claimableAmount1, largeDeposit.amount);

        (address claimableTo2, uint256 claimableAmount2) = bridgeContract.claimableNative(depositData2.nonce);
        assertEq(claimableTo2, address(0));
        assertEq(claimableAmount2, 0);
    }

    function test_BridgeThreeDepositsWithInsufficientFundsForExecutingTheSecondDeposit() public {
        uint256 bridgeContractBalance = address(bridgeContract).balance;

        BridgeLib.DepositData memory smallDeposit1 =
            BridgeLib.DepositData({nonce: 1, to: payable(validator2), amount: 12});
        BridgeLib.DepositData memory largeDeposit =
            BridgeLib.DepositData({nonce: 2, to: payable(validator1), amount: 10000000001}); // Large amount > bridge balance
        BridgeLib.DepositData memory smallDeposit3 =
            BridgeLib.DepositData({nonce: 3, to: payable(validator3), amount: 13});

        assertTrue(toEthDecimals(smallDeposit1.amount) <= bridgeContractBalance);
        assertTrue(toEthDecimals(largeDeposit.amount) > bridgeContractBalance);
        assertTrue(toEthDecimals(smallDeposit3.amount) <= bridgeContractBalance);

        bytes32 root1 = computeRoot(
            bytes32(0), hashDepositOrWithdrawal(uint64(smallDeposit1.nonce), smallDeposit1.to, smallDeposit1.amount)
        );
        bytes32 root2 = computeRoot(
            root1, hashDepositOrWithdrawal(uint64(largeDeposit.nonce), largeDeposit.to, largeDeposit.amount)
        );
        bytes32 newRoot = computeRoot(
            root2, hashDepositOrWithdrawal(uint64(smallDeposit3.nonce), smallDeposit3.to, smallDeposit3.amount)
        );

        BridgeLib.Signature[] memory signatures;
        BridgeLib.DepositData[] memory deposits;
        {
            uint256[] memory validatorIndices = new uint256[](5);
            validatorIndices[0] = 1;
            validatorIndices[1] = 2;
            validatorIndices[2] = 3;
            validatorIndices[3] = 4;
            validatorIndices[4] = 5;
            signatures = getValidatorSignatures(newRoot, validatorIndices);

            deposits = new BridgeLib.DepositData[](3);
            deposits[0] = smallDeposit1;
            deposits[1] = largeDeposit;
            deposits[2] = smallDeposit3;
        }
        {
            uint256 bridgeBalanceBefore = address(bridgeContract).balance;
            uint256 deposit1RecipientBalanceBefore = smallDeposit1.to.balance;
            uint256 largeDepositRecipientBalanceBefore = largeDeposit.to.balance;
            uint256 deposit3RecipientBalanceBefore = smallDeposit3.to.balance;

            vm.prank(relayer);
            vm.expectEmit(true, true, true, false);
            emit INativeBridge.NativeClaimable(largeDeposit.nonce, largeDeposit.to, largeDeposit.amount);
            bridgeContract.depositNative(newRoot, signatures, deposits);

            // Check the balance changes - only smallDeposit1 and smallDeposit3 should be paid out
            assertEq(
                address(bridgeContract).balance,
                bridgeBalanceBefore - toEthDecimals(smallDeposit1.amount) - toEthDecimals(smallDeposit3.amount)
            );
            assertEq(smallDeposit1.to.balance, deposit1RecipientBalanceBefore + toEthDecimals(smallDeposit1.amount));
            assertEq(largeDeposit.to.balance, largeDepositRecipientBalanceBefore); // No change
            assertEq(smallDeposit3.to.balance, deposit3RecipientBalanceBefore + toEthDecimals(smallDeposit3.amount));

            (, StorageTypes.State memory depositState,,) = bridgeContract.nativeBridge();
            assertEq(depositState.nonce, smallDeposit3.nonce);
            assertEq(depositState.root, newRoot);
        }

        // Check claimable states
        (address claimableTo1, uint256 claimableAmount1) = bridgeContract.claimableNative(smallDeposit1.nonce);
        assertEq(claimableTo1, address(0));
        assertEq(claimableAmount1, 0);

        (address claimableTo2, uint256 claimableAmount2) = bridgeContract.claimableNative(largeDeposit.nonce);
        assertEq(claimableTo2, largeDeposit.to);
        assertEq(claimableAmount2, largeDeposit.amount);

        (address claimableTo3, uint256 claimableAmount3) = bridgeContract.claimableNative(smallDeposit3.nonce);
        assertEq(claimableTo3, address(0));
        assertEq(claimableAmount3, 0);
    }

    function test_DepositWhenRecipientIsContract() public {
        BridgeLib.DepositData memory contractDeposit =
            BridgeLib.DepositData({nonce: 2, amount: 200000000, to: payable(address(bridgeContract))});

        bytes32 hashDepositData1 =
            hashDepositOrWithdrawal(uint64(depositData1.nonce), depositData1.to, depositData1.amount);
        bytes32 hashDepositData2 =
            hashDepositOrWithdrawal(uint64(contractDeposit.nonce), contractDeposit.to, contractDeposit.amount);
        bytes32 root1 = computeRoot(bytes32(0), hashDepositData1);
        bytes32 newRoot = computeRoot(root1, hashDepositData2);

        BridgeLib.Signature[] memory signatures;
        BridgeLib.DepositData[] memory deposits;
        {
            uint256[] memory validatorIndices = new uint256[](5);
            validatorIndices[0] = 1;
            validatorIndices[1] = 2;
            validatorIndices[2] = 3;
            validatorIndices[3] = 4;
            validatorIndices[4] = 5;
            signatures = getValidatorSignatures(newRoot, validatorIndices);

            deposits = new BridgeLib.DepositData[](2);
            deposits[0] = depositData1;
            deposits[1] = contractDeposit;
        }
        uint256 bridgeBalanceBefore = address(bridgeContract).balance;
        uint256 deposit1RecipientBalanceBefore = depositData1.to.balance;

        vm.prank(relayer);
        bridgeContract.depositNative(newRoot, signatures, deposits);

        assertEq(address(bridgeContract).balance, bridgeBalanceBefore - toEthDecimals(depositData1.amount));
        assertEq(depositData1.to.balance, deposit1RecipientBalanceBefore + toEthDecimals(depositData1.amount));

        (, StorageTypes.State memory depositState,,) = bridgeContract.nativeBridge();
        assertEq(depositState.nonce, contractDeposit.nonce);
        assertEq(depositState.root, newRoot);

        // Check claimable table changes
        (address claimableTo1, uint256 claimableAmount1) = bridgeContract.claimableNative(depositData1.nonce);
        assertEq(claimableTo1, address(0));
        assertEq(claimableAmount1, 0);

        (address claimableTo2, uint256 claimableAmount2) = bridgeContract.claimableNative(contractDeposit.nonce);
        assertEq(claimableTo2, contractDeposit.to);
        assertEq(claimableAmount2, contractDeposit.amount);
    }

    function test_DepositWhenDepositLengthIsEqualTo10() public {
        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](10);
        uint256 nrDeposits = 10;
        bytes32 hashResult = bytes32(0);

        for (uint256 i = 0; i < nrDeposits; i++) {
            deposits[i] = BridgeLib.DepositData({nonce: uint64(i + 1), amount: 100000000, to: payable(relayer)});
            hashResult = computeRoot(hashResult, hashDepositOrWithdrawal(uint64(i + 1), relayer, 100000000));
        }

        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(hashResult, validatorIndices);

        uint256 bridgeBalanceBefore = address(bridgeContract).balance;
        uint256 relayerBalanceBefore = relayer.balance;

        vm.prank(relayer);
        vm.expectEmit(true, true, false, false);
        emit INativeBridge.NativeDepositRootUpdate(10, hashResult);
        bridgeContract.depositNative(hashResult, signatures, deposits);

        assertEq(address(bridgeContract).balance, bridgeBalanceBefore - toEthDecimals(deposits[0].amount * nrDeposits));
        assertEq(relayer.balance, relayerBalanceBefore + toEthDecimals(deposits[0].amount * nrDeposits));

        (, StorageTypes.State memory depositState,,) = bridgeContract.nativeBridge();
        assertEq(depositState.nonce, 10);
        assertEq(depositState.root, hashResult);
    }

    function test_DepositWhenRecipientAddressIsZeroAddress() public {
        BridgeLib.DepositData memory zeroAddressDeposit =
            BridgeLib.DepositData({nonce: 1, amount: 100000000, to: payable(address(0))});
        bytes32 root = computeRoot(
            bytes32(0),
            hashDepositOrWithdrawal(uint64(zeroAddressDeposit.nonce), zeroAddressDeposit.to, zeroAddressDeposit.amount)
        );

        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(root, validatorIndices);

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = zeroAddressDeposit;

        uint256 bridgeBalanceBefore = address(bridgeContract).balance;

        vm.prank(relayer);
        vm.expectEmit(true, true, true, false);
        emit INativeBridge.NativeDepositRootUpdate(zeroAddressDeposit.nonce, root);
        vm.expectEmit(true, true, true, false);
        emit INativeBridge.NativeDeposit(zeroAddressDeposit.nonce, zeroAddressDeposit.to, zeroAddressDeposit.amount);
        bridgeContract.depositNative(root, signatures, deposits);

        // Bridge balance should decrease for zero address deposit (funds are burned)
        assertEq(address(bridgeContract).balance, bridgeBalanceBefore - toEthDecimals(zeroAddressDeposit.amount));
        // Asert zero address has balance increased
        assertEq(address(0).balance, toEthDecimals(zeroAddressDeposit.amount));

        (, StorageTypes.State memory depositState,,) = bridgeContract.nativeBridge();
        assertEq(depositState.nonce, zeroAddressDeposit.nonce);
        assertEq(depositState.root, root);
    }

    function test_ShouldRevertWhenSignatureLengthIs5ButWithTwoDuplicateSignature() public {
        bytes32 hashDepositData1 =
            hashDepositOrWithdrawal(uint64(depositData1.nonce), depositData1.to, depositData1.amount);
        bytes32 root1 = computeRoot(bytes32(0), hashDepositData1);

        // Create signatures with duplicate (using validator 1 twice)
        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 1; // Duplicate
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(root1, validatorIndices);

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = depositData1;

        vm.prank(relayer);
        vm.expectRevert();
        bridgeContract.depositNative(root1, signatures, deposits);
    }

    function test_ShouldRevertWhenSignatureVerifyFailed() public {
        bytes32 hashDepositData1 =
            hashDepositOrWithdrawal(uint64(depositData1.nonce), depositData1.to, depositData1.amount);
        bytes32 root1 = computeRoot(bytes32(0), hashDepositData1);
        bytes32 wrongRoot = computeRoot(bytes32(0), hashDepositOrWithdrawal(2, depositData1.to, depositData1.amount)); // Wrong root

        // Generate signatures for the wrong root
        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(wrongRoot, validatorIndices);

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = depositData1;

        vm.prank(relayer);
        vm.expectRevert();
        bridgeContract.depositNative(root1, signatures, deposits); // Using correct root but wrong signatures
    }

    function test_ShouldRevertWhenRootIsInvalid() public {
        bytes32 correctRoot = computeRoot(
            bytes32(0), hashDepositOrWithdrawal(uint64(depositData1.nonce), depositData1.to, depositData1.amount)
        );
        bytes32 invalidRoot = bytes32(uint256(0x123456)); // Invalid root

        uint256[] memory validatorIndices = new uint256[](5);
        validatorIndices[0] = 1;
        validatorIndices[1] = 2;
        validatorIndices[2] = 3;
        validatorIndices[3] = 4;
        validatorIndices[4] = 5;
        BridgeLib.Signature[] memory signatures = getValidatorSignatures(correctRoot, validatorIndices);

        BridgeLib.DepositData[] memory deposits = new BridgeLib.DepositData[](1);
        deposits[0] = depositData1;

        vm.prank(relayer);
        vm.expectRevert();
        bridgeContract.depositNative(invalidRoot, signatures, deposits);
    }

    function test_WithdrawWithDifferentFeesAndVerifyUnclaimedRewards() public {
        (,,, StorageTypes.NativeConfig memory config) = bridgeContract.nativeBridge();
        uint256 withdrawalFee1 = config.fee;
        uint256 withdrawalAmount1 = 1 ether;
        uint256 withdrawalFee2 = 0.2 ether;
        uint256 withdrawalAmount2 = 2 ether;

        vm.deal(relayer, withdrawalAmount1 + withdrawalFee1 + withdrawalAmount2 + withdrawalFee2);

        uint256 bridgeBalanceBefore = address(bridgeContract).balance;

        // First withdrawal with standard fee
        vm.prank(relayer);
        bridgeContract.withdrawNative{value: withdrawalAmount1 + withdrawalFee1}(relayer, withdrawalFee1);

        // Second withdrawal with different fee
        vm.prank(relayer);
        bridgeContract.withdrawNative{value: withdrawalAmount2 + withdrawalFee2}(validator1, withdrawalFee2);

        // Verify both withdrawals were processed and fees were collected
        uint256 bridgeBalanceAfter = address(bridgeContract).balance;
        uint256 expectedIncrease = withdrawalAmount1 + withdrawalFee1 + withdrawalAmount2 + withdrawalFee2;
        assertEq(bridgeBalanceAfter, bridgeBalanceBefore + expectedIncrease);

        (,, StorageTypes.State memory withdrawalState,) = bridgeContract.nativeBridge();
        assertEq(withdrawalState.nonce, 2);
    }
}

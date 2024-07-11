// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import {TestBridge, BridgeImpl} from "../contracts/tests/TestBridge.sol";
import {IERC20Errors} from "../node_modules/@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ITokenBridge} from "../contracts/interfaces/ITokenBridge.sol";
import {BridgeStorage, BridgeLib, GasBridgeLib, StorageTypes, TokenBridgeLib} from "../contracts/bridge/BridgeStorage.sol";
import "../contracts/management/BridgeManagementImpl.sol";
import "../contracts/tests/SigUtils.sol";
import "../contracts/tests/MockERC20.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract TokenBridgeSyncTest is Test, SigUtils {
    TestBridge bridgeProxy;
    address managementProxyAddress;
    address bridgeProxyAddress;

    MockERC20 neoXNeoTokenContract;

    address neoXNeoToken = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f;
    address neoN3NeoToken = 0xEf4073A0F2b305a38EC4050e4d3d28bC40eA63F5;
    StorageTypes.TokenConfig neoBridgeConfig;

    // set _management
    BridgeManagementImpl bridgeManagementImpl;
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

    address withdrawingAccount = 0xd1bb122c647aB57eA3d8D321bAACD5e05eD2e5AA;

    function setUp() public {
        // Deploy the token first, so that its addresses stay the same even if more transactions are added in the setup in the future.
        neoXNeoTokenContract = new MockERC20("NeoToken", "NEO");
        address neoToken = address(neoXNeoTokenContract);
        assertEq(neoToken, neoXNeoToken);
        assertEq(neoXNeoTokenContract.decimals(), 18);

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
        // Deploy the bridge management implementation behind a UUPS proxy and initialize it with the provided parameters.
        managementProxyAddress = Upgrades.deployUUPSProxy(
            "BridgeManagementImpl.sol",
            abi.encodeCall(
                BridgeManagementImpl.initialize,
                (
                    owner,
                    relayer,
                    5,
                    validatorsAddresses,
                    governor,
                    securityGuard,
                    funder
                )
            ),
            opts
        );
        bridgeManagementImpl = BridgeManagementImpl(managementProxyAddress);

        // Deploy the bridge implementation behind a UUPS proxy and initialize it with the provided parameters.
        bridgeProxyAddress = Upgrades.deployUUPSProxy(
            "TestBridge.sol",
            abi.encodeCall(
                BridgeImpl.initialize,
                (managementProxyAddress, 1e17, 1e18, 1e22, 100)
            ),
            opts
        );
        bridgeProxy = TestBridge(payable(bridgeProxyAddress));

        neoBridgeConfig = StorageTypes.TokenConfig({
            neoN3Token: neoN3NeoToken,
            fee: 0.1 ether,
            minAmount: 1,
            maxAmount: 1000 ether,
            maxDeposits: 2,
            executionType: StorageTypes.ExecutionType.NEO
        });

        // Fund the test accounts with some ether.
        vm.deal(funder, 1 ether);
        vm.deal(owner, 1 ether);
        vm.deal(withdrawingAccount, 1 ether);

        MockERC20(neoXNeoToken).mint(address(bridgeProxy), 1000 ether);
        assertEq(
            neoXNeoTokenContract.balanceOf(address(bridgeProxy)),
            1000 ether
        );

        vm.prank(governor);
        bridgeProxy.registerToken(neoXNeoToken, neoBridgeConfig);
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

    function testHashBridgeOp() public view {
        uint256 nonce = 330500;
        address to = address(0xD44304966f6e74cfd0E2215649D5C57892BfBAaB);
        uint256 value = 1234567890;
        assertEq(neoXNeoToken, 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f);
        assertEq(neoN3NeoToken, 0xEf4073A0F2b305a38EC4050e4d3d28bC40eA63F5);

        bytes32 hashedBridgeOp = bridgeProxy.hashTokenBridgeOp(
            neoXNeoToken,
            neoN3NeoToken,
            nonce,
            to,
            value
        );
        bytes memory concatenated = abi.encodePacked(
            neoN3NeoToken,
            neoXNeoToken,
            nonce,
            to,
            value
        );
        assertEq(
            concatenated,
            hex"Ef4073A0F2b305a38EC4050e4d3d28bC40eA63F55615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000000000000000000000000000000000000000000000000000000050b04D44304966f6e74cfd0E2215649D5C57892BfBAaB00000000000000000000000000000000000000000000000000000000499602d2"
        );
        bytes32 expected = sha256(concatenated);
        assertEq(hashedBridgeOp, expected);
        assertEq(
            hashedBridgeOp,
            hex"5dcc8d59cfb9446288dc79f3e2a776d05e7bce0b82efe28ec554d6dcb08acda4"
        );
    }

    function testDepositNeo() public {
        address recipientOnNeoX_1 = 0xF3D4D6320dd41f14B8Fa6550a6F33c46c6F44407;
        address recipientOnNeoX_2 = 0x3220a7ee654E1f84f13E8021B7E2b09775E1BDf2;

        // Verify the signatures of 6 validators
        vm.prank(owner);
        bridgeManagementImpl.setValidators(validatorsAddresses, 6);

        BridgeLib.DepositData[]
            memory depositData = new BridgeLib.DepositData[](2);

        BridgeLib.DepositData memory d0 = BridgeLib.DepositData({
            nonce: 1,
            to: payable(recipientOnNeoX_1),
            amount: 355
        });
        BridgeLib.DepositData memory d1 = BridgeLib.DepositData({
            nonce: 2,
            to: payable(recipientOnNeoX_2),
            amount: 445
        });

        depositData[0] = d0;
        depositData[1] = d1;
        bytes32 tokenDepositRoot = bridgeProxy.computeTokenRoot(
            bridgeProxy.getTokenDepositState(neoXNeoToken).root,
            neoN3NeoToken,
            neoXNeoToken,
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
            neoXNeoToken,
            neoN3NeoToken,
            d1.nonce,
            tokenDepositRoot
        );
        bridgeProxy.depositToken(
            neoXNeoToken,
            tokenDepositRoot,
            signatures,
            depositData
        );
        // check balances
        assertEq(neoXNeoTokenContract.balanceOf(recipientOnNeoX_1), 355 ether);
        assertEq(neoXNeoTokenContract.balanceOf(recipientOnNeoX_2), 445 ether);
        assertEq(
            tokenDepositRoot,
            0x6c995cd010e797f62716b58053fbfbf4834c68d96c5f0361bf49186cbef6d457
        );
    }

    function testWithdrawNeo() public {
        neoXNeoTokenContract.mint(withdrawingAccount, 1000 ether);

        address recipientOnNeoN3_1 = 0xDA1fE5cf6Eb14785aA9d4dCC7bc87aab7DEcb625;
        uint256 amount_1 = 12 ether;
        address recipientOnNeoN3_2 = 0xC17940c0bf2A801266f3669c19E0c594e751f868;
        uint256 amount_2 = 1 ether;
        address recipientOnNeoN3_3 = 0x278bc15652D2cBF8a1a098843a659Cf300760e2e;
        uint256 amount_3 = 196 ether;

        uint256 withdrawalFee = bridgeProxy.getTokenConfig(neoXNeoToken).fee;

        vm.prank(withdrawingAccount);
        neoXNeoTokenContract.approve(address(bridgeProxy), 209 ether);
        vm.prank(withdrawingAccount);
        bridgeProxy.withdrawToken{value: withdrawalFee}(
            neoXNeoToken,
            recipientOnNeoN3_1,
            amount_1
        );

        vm.prank(withdrawingAccount);
        bridgeProxy.withdrawToken{value: withdrawalFee}(
            neoXNeoToken,
            recipientOnNeoN3_2,
            amount_2
        );

        vm.prank(withdrawingAccount);
        bridgeProxy.withdrawToken{value: withdrawalFee}(
            neoXNeoToken,
            recipientOnNeoN3_3,
            amount_3
        );

        StorageTypes.State memory state = bridgeProxy.getTokenWithdrawalState(
            neoXNeoToken
        );
        assertEq(state.nonce, 3);
        assertEq(
            state.root,
            0x2b1eb8388620f2ba81eeecda0b88c41a35d8aef678cb1eb22ecc488b087d9c99
        );
    }
}

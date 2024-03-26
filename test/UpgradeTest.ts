import { expect } from "chai";
import { ethers, storageLayout } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { getValidatorSignatures } from "../utils/signature-utils";
import {
    toEthDecimals, hashDepositOrWithdrawal, fundContract, computeRoot, validator1, validator2, validator3
} from "./helper";
import { BridgeContract } from "../typechain-types/contracts/BridgeContract";
import { BridgeProxy } from "../typechain-types/contracts/BridgeProxy";
import { TestBridgeImplV2 } from "../typechain-types/contracts/tests/TestBridgeImplV2";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

const Depositdata1 = { to: validator1, amount: 100000000n, nonce: 1 };
const Depositdata2 = { to: validator2, amount: 100000000n, nonce: 2 };
const Depositdata3 = { to: validator3, amount: 200000000n, nonce: 3 };

describe("Bridge Implementation", function () {
    async function deployBridgeFixture() {
        const [
            relayer,
            validator1,
            validator2,
            validator3,
            validator4,
            validator5,
            validator6,
            validator7,
            governor,
            securityGuard,
            proxyOwner
        ] = await ethers.getSigners();
        const BridgeManagementFactory = await ethers.getContractFactory("BridgeManagementContract");
        const bridgeManagementContract = await BridgeManagementFactory.deploy();
        await bridgeManagementContract.waitForDeployment();
        const bridgeManagementAddress = await bridgeManagementContract.getAddress();

        const BridgeFactory = await ethers.getContractFactory("BridgeContract");
        const bridgeImplV1 = await BridgeFactory.deploy();
        await bridgeImplV1.waitForDeployment();
        const bridgeImplV1Address = await bridgeImplV1.getAddress();

        const TestBridgeImplV2 = await ethers.getContractFactory("TestBridgeImplV2");
        const bridgeImplV2 = await TestBridgeImplV2.deploy();
        await bridgeImplV2.waitForDeployment();
        const bridgeImplV2Address = await bridgeImplV2.getAddress();

        const proxyFactory = await ethers.getContractFactory("BridgeProxy");
        const proxyContract = await proxyFactory.connect(proxyOwner).deploy(bridgeImplV1Address);
        await proxyContract.waitForDeployment();
        const proxyAddress = await proxyContract.getAddress();

        // These are both pointing to the same proxy contract, but provide different interfaces to use.
        // proxy provides the interface of the initial implementation, while proxyV2 provides the interface of the upgraded implementation.
        const proxy = new ethers.Contract(proxyAddress, bridgeImplV1.interface, validator1) as unknown as BridgeContract;
        const proxyV2 = new ethers.Contract(proxyAddress, bridgeImplV2.interface, validator2) as unknown as TestBridgeImplV2;

        await fundContract(proxy, relayer);

        await proxy.initialize(bridgeManagementAddress, {
            fee: ethers.parseEther("0.1"),
            minAmount: ethers.parseEther("1"),
            maxAmount: ethers.parseEther("10000"),
            maxDepositsPerDistribution: 100,
            gap: [0, 0]
        });

        return {
            bridgeManagementContract: bridgeManagementContract,
            bridgeImplV1Contract: bridgeImplV1,
            bridgeImplV2Contract: bridgeImplV2,
            proxyContract: proxyContract,
            proxy: proxy,
            proxyV2: proxyV2,
            proxyOwner,
            relayer,
            validator1,
            validator2,
            validator3,
            validator4,
            validator5,
            validator6,
            validator7,
            governor,
            securityGuard,
        }
    }

    async function upgradeProxyImplementation(bridgeImplV1Contract: BridgeContract, bridgeImplV2Contract: TestBridgeImplV2, proxyContract: BridgeProxy, proxyOwner: HardhatEthersSigner) {
        const oldImplementationAddress = await bridgeImplV1Contract.getAddress();
        const newImplementationAddress = await bridgeImplV2Contract.getAddress();
        expect(await proxyContract.implementation()).to.be.equal(oldImplementationAddress);
        expect(await proxyOwner.getAddress()).to.be.equal(await proxyContract.owner());
        await proxyContract.connect(proxyOwner).upgrade(newImplementationAddress);
        expect(await proxyContract.implementation()).to.be.equal(newImplementationAddress);
    }

    describe("Upgrade Test", function () {
        it("Verify initialization", async function () {
            const { proxy, proxyV2, bridgeImplV1Contract, bridgeImplV2Contract, bridgeManagementContract } = await loadFixture(deployBridgeFixture);
            expect(await bridgeImplV1Contract.managementContract()).to.be.equal(ethers.ZeroAddress);
            expect(await bridgeImplV2Contract.managementContract()).to.be.equal(ethers.ZeroAddress);
            expect(await proxy.managementContract()).to.be.equal(await bridgeManagementContract.getAddress());
        });

        it("Verify Balances", async function () {
            const { proxy, proxyV2, bridgeImplV1Contract, bridgeImplV2Contract } = await loadFixture(deployBridgeFixture);
            expect(await proxyV2.getAddress()).to.be.equal(await proxyV2.getAddress());
            expect(await ethers.provider.getBalance(await proxy.getAddress())).to.be.equal(ethers.parseEther("100.0"));
            expect(await ethers.provider.getBalance(await proxyV2.getAddress())).to.be.equal(ethers.parseEther("100.0"));
            expect(await ethers.provider.getBalance(await bridgeImplV1Contract.getAddress())).to.be.equal(0);
            expect(await ethers.provider.getBalance(await bridgeImplV2Contract.getAddress())).to.be.equal(0);
        });

        it("Verify GAS bridge configuration", async function () {
            const { proxy, proxyV2, bridgeImplV1Contract, bridgeImplV2Contract } = await loadFixture(deployBridgeFixture);
            const gasBridge = await proxyV2.gasBridge();
            expect(gasBridge.config.fee).to.be.equal(ethers.parseEther("0.1"));
            expect(gasBridge.config.minAmount).to.be.equal(ethers.parseEther("1"));
            expect(gasBridge.config.maxAmount).to.be.equal(ethers.parseEther("10000"));
            expect(gasBridge.config.maxDepositsPerDistribution).to.be.equal(100);
        });

        it("Remove onlyRelayer modifier", async function () {
            const { proxy, proxyV2, proxyContract, proxyOwner, bridgeImplV1Contract, bridgeImplV2Contract, relayer, validator1, validator7 } = await loadFixture(deployBridgeFixture);
            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures1 = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            // Only the relayer can call the deposit function
            let tx = proxy.connect(validator1).deposit(root1, signatures1, [Depositdata1]);
            expect(tx).to.be.revertedWith("Not relayer");
            tx = proxy.connect(relayer).deposit(root1, signatures1, [Depositdata1]);
            expect(tx).to.changeEtherBalances([proxy, Depositdata1.to], [-toEthDecimals(Depositdata1.amount), toEthDecimals(Depositdata1.amount)]);

            // Upgrade
            await upgradeProxyImplementation(bridgeImplV1Contract, bridgeImplV2Contract, proxyContract, proxyOwner);

            const hashDepositData2 = await hashDepositOrWithdrawal(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);
            const root2 = await computeRoot(root1, hashDepositData2);
            const encodeRoot2 = ethers.solidityPackedKeccak256(["bytes32"], [root2]);
            const signatures2 = await getValidatorSignatures(ethers.getBytes(encodeRoot2), [1, 2, 3, 4, 5]);

            // Now, after the upgrade, anyone can call the deposit function
            tx = proxy.connect(validator7).deposit(root2, signatures2, [Depositdata2]);
            expect(tx).to.changeEtherBalances([proxy, Depositdata2.to], [-toEthDecimals(Depositdata2.amount), toEthDecimals(Depositdata2.amount)]);
        });

        it("Add new mapping and new function", async function () {
            const { proxy, proxyV2, proxyContract, proxyOwner, bridgeImplV1Contract, bridgeImplV2Contract, relayer, validator1, validator7 } = await loadFixture(deployBridgeFixture);
            const tx = proxyV2.isRegistered(validator1.address);
            expect(tx).to.be.revertedWithoutReason();
            const txRegister = proxyV2.register(validator1.address);
            expect(txRegister).to.be.revertedWithoutReason();

            // Upgrade
            await upgradeProxyImplementation(bridgeImplV1Contract, bridgeImplV2Contract, proxyContract, proxyOwner);

            let registered = await proxyV2.isRegistered(validator1.address);
            expect(registered).to.be.false;
            await proxyV2.register(validator1.address);
            registered = await proxyV2.isRegistered(validator1.address);
            expect(registered).to.be.true;
        });

        it("Use overridden function", async function () {
            const { proxy, proxyV2, proxyContract, proxyOwner, bridgeImplV1Contract, bridgeImplV2Contract, governor } = await loadFixture(deployBridgeFixture);
            await proxyV2.connect(governor).setGasWithdrawalFee(ethers.parseEther("0.2"));
            expect((await proxyV2.gasBridge()).config.fee).to.be.equal(ethers.parseEther("0.2"));

            // Upgrade
            await upgradeProxyImplementation(bridgeImplV1Contract, bridgeImplV2Contract, proxyContract, proxyOwner);

            let tx = proxyV2.connect(governor).setGasWithdrawalFee(ethers.parseEther("0.3"));
            expect(tx).to.be.revertedWith("Fee must be at least 1 gas");
            await proxyV2.connect(governor).setGasWithdrawalFee(ethers.parseEther("1"));
            expect((await proxyV2.gasBridge()).config.fee).to.be.equal(ethers.parseEther("1"));
        });
    });
});

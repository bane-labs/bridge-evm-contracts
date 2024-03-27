import { expect } from "chai";
import { ethers, upgrades, storageLayout } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { getValidatorSignatures } from "../utils/signature-utils";
import {
    toEthDecimals, hashDepositOrWithdrawal, fundContract, computeRoot, validator1, validator2, validator3
} from "./helper";
import { BridgeImpl } from "../typechain-types/contracts/BridgeImpl";
import { TestBridgeImplV2 } from "../typechain-types/contracts/tests/TestBridgeImplV2";

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

        const BridgeFactory = await ethers.getContractFactory("BridgeImpl");
        const TestBridgeImplV2Factory = await ethers.getContractFactory("TestBridgeImplV2");

        const initializeData = [bridgeManagementAddress, {
            fee: ethers.parseEther("0.1"),
            minAmount: ethers.parseEther("1"),
            maxAmount: ethers.parseEther("10000"),
            maxDepositsPerDistribution: 100,
            gap: [0, 0]
        }];
        const proxyContract = await upgrades.deployProxy(BridgeFactory, initializeData, { initializer: "initialize", kind: "transparent" });
        await proxyContract.waitForDeployment();
        const proxyAddress = await proxyContract.getAddress()

        // These are both pointing to the same proxy contract, but provide different interfaces to use.
        // proxy provides the interface of the initial implementation, while proxyV2 provides the interface of the upgraded implementation.
        const proxyV1 = new ethers.Contract(proxyAddress, BridgeFactory.interface, validator1) as unknown as BridgeImpl;
        const proxyV2 = new ethers.Contract(proxyAddress, TestBridgeImplV2Factory.interface, validator2) as unknown as TestBridgeImplV2;

        await fundContract(proxyContract, relayer);

        return {
            bridgeManagementContract: bridgeManagementContract,
            BridgeImplV2Factory: TestBridgeImplV2Factory,
            proxyContract: proxyContract,
            proxyV1: proxyV1,
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

    describe("Upgrade Test", function () {
        it("Verify initialization", async function () {
            const { proxyV1: proxy, proxyV2, bridgeManagementContract } = await loadFixture(deployBridgeFixture);
            expect(await proxy.managementContract()).to.be.equal(await bridgeManagementContract.getAddress());
        });

        it("Verify Balances", async function () {
            const { proxyV1: proxy, proxyV2 } = await loadFixture(deployBridgeFixture);
            expect(await proxyV2.getAddress()).to.be.equal(await proxyV2.getAddress());
            expect(await ethers.provider.getBalance(await proxy.getAddress())).to.be.equal(ethers.parseEther("100.0"));
            expect(await ethers.provider.getBalance(await proxyV2.getAddress())).to.be.equal(ethers.parseEther("100.0"));
        });

        it("Verify GAS bridge configuration", async function () {
            const { proxyV1: proxy, proxyV2 } = await loadFixture(deployBridgeFixture);
            const gasBridge = await proxyV2.gasBridge();
            expect(gasBridge.config.fee).to.be.equal(ethers.parseEther("0.1"));
            expect(gasBridge.config.minAmount).to.be.equal(ethers.parseEther("1"));
            expect(gasBridge.config.maxAmount).to.be.equal(ethers.parseEther("10000"));
            expect(gasBridge.config.maxDepositsPerDistribution).to.be.equal(100);
        });

        it("Remove onlyRelayer modifier", async function () {
            const { proxyV1: proxy, BridgeImplV2Factory, proxyContract, relayer, validator1, validator7 } = await loadFixture(deployBridgeFixture);
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
            const contract = upgrades.upgradeProxy(await proxyContract.getAddress(), BridgeImplV2Factory, { kind: "transparent" });
            expect(await contract).to.emit(contract, "Upgraded");

            const hashDepositData2 = await hashDepositOrWithdrawal(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);
            const root2 = await computeRoot(root1, hashDepositData2);
            const encodeRoot2 = ethers.solidityPackedKeccak256(["bytes32"], [root2]);
            const signatures2 = await getValidatorSignatures(ethers.getBytes(encodeRoot2), [1, 2, 3, 4, 5]);

            // Now, after the upgrade, anyone can call the deposit function
            tx = proxy.connect(validator7).deposit(root2, signatures2, [Depositdata2]);
            expect(tx).to.changeEtherBalances([proxy, Depositdata2.to], [-toEthDecimals(Depositdata2.amount), toEthDecimals(Depositdata2.amount)]);
        });

        it("Add new mapping and new function", async function () {
            const { proxyV1: proxy, proxyV2, BridgeImplV2Factory, proxyContract, validator1 } = await loadFixture(deployBridgeFixture);
            const tx = proxyV2.isRegistered(validator1.address);
            expect(tx).to.be.revertedWithoutReason();
            const txRegister = proxyV2.register(validator1.address);
            expect(txRegister).to.be.revertedWithoutReason();

            // Upgrade
            const contract = upgrades.upgradeProxy(await proxyContract.getAddress(), BridgeImplV2Factory, { kind: "transparent" });
            expect(await contract).to.emit(contract, "Upgraded");

            let registered = await proxyV2.isRegistered(validator1.address);
            expect(registered).to.be.false;
            await proxyV2.register(validator1.address);
            registered = await proxyV2.isRegistered(validator1.address);
            expect(registered).to.be.true;
        });

        it("Use overridden function", async function () {
            const { proxyV2, BridgeImplV2Factory, proxyContract, governor } = await loadFixture(deployBridgeFixture);
            await proxyV2.connect(governor).setGasWithdrawalFee(ethers.parseEther("0.2"));
            expect((await proxyV2.gasBridge()).config.fee).to.be.equal(ethers.parseEther("0.2"));

            // Upgrade
            const contract = upgrades.upgradeProxy(await proxyContract.getAddress(), BridgeImplV2Factory, { kind: "transparent" });
            expect(await contract).to.emit(contract, "Upgraded");

            let tx = proxyV2.connect(governor).setGasWithdrawalFee(ethers.parseEther("0.3"));
            expect(tx).to.be.revertedWith("Fee must be at least 1 gas");
            await proxyV2.connect(governor).setGasWithdrawalFee(ethers.parseEther("1"));
            expect((await proxyV2.gasBridge()).config.fee).to.be.equal(ethers.parseEther("1"));
        });
    });
});

import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { getValidatorSignatures } from "../utils/signature-utils";
import {
    to1, to2, to3, to4, to5, to6, to7, to8, to9, to0,
    toEthDecimals, toNeoDecimals, hashDepositOrWithdrawal, computeRoot, validator1, validator2, validator3, validator7
} from "./helper";

const Depositdata1 = { nonce: 1, to: validator1, amount: 100000000n };
const Depositdata2 = { nonce: 2, to: validator2, amount: 200000000n };
const Depositdata3 = { nonce: 3, to: validator3, amount: 300000000n };

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
            managementOwner,
            deployer,
            funder
        ] = await ethers.getSigners();

        const BridgeManagementFactory = (await ethers.getContractFactory("BridgeManagementImpl"));
        const bridgeManagementProxy = await upgrades.deployProxy(BridgeManagementFactory, [
            managementOwner.address,
            relayer.address,
            5,
            [validator1.address, validator2.address, validator3.address, validator4.address, validator5.address, validator6.address, validator7.address],
            governor.address,
            securityGuard.address,
            funder.address
        ], { kind: "uups", unsafeAllow: ["constructor"] });
        await bridgeManagementProxy.waitForDeployment();
        const bridgeManagement = bridgeManagementProxy as BridgeManagementImpl;

        const BridgeContractFactory = await ethers.getContractFactory("BridgeImpl");
        const bridgeProxy = await upgrades.deployProxy(BridgeContractFactory, [await bridgeManagement.getAddress(), ethers.parseEther("0.1"), ethers.parseEther("1"), ethers.parseEther("10000"), 100], { kind: "uups", unsafeAllow: ["constructor"] });
        await bridgeProxy.waitForDeployment();
        const bridge = bridgeProxy as BridgeImpl;

        // Fund the bridge contract.
        await funder.sendTransaction({ to: bridge, value: ethers.parseEther("80.0") });

        return {
            bridgeContract: bridge,
            bridgeManagementContract: bridgeManagement,
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
            managementOwner,
            deployer,
            funder
        }
    }

    describe("Parameter setters", function () {
        it("Set withdrawal fee", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const oldFee = ethers.parseEther("0.1");
            let gasBridge = await bridgeContract.gasBridge()
            expect(gasBridge.config.fee).to.be.equal(oldFee);
            const newFee = ethers.parseEther("0.2");
            const tx = await bridgeContract.connect(governor).setGasWithdrawalFee(newFee);
            await expect(tx).to.emit(bridgeContract, "GasWithdrawalFeeChange").withArgs(newFee);
            gasBridge = await bridgeContract.gasBridge();
            expect(gasBridge.config.fee).to.be.equal(newFee);
        });

        it("Set min withdrawal amount", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const oldMinAmount = ethers.parseEther("1");
            expect((await bridgeContract.gasBridge()).config.minAmount).to.be.equal(oldMinAmount);
            const newMinAmount = ethers.parseEther("0.2");
            const tx = await bridgeContract.connect(governor).setMinGasWithdrawalAmount(newMinAmount);
            await expect(tx).to.emit(bridgeContract, "MinGasWithdrawalChange").withArgs(newMinAmount);
            expect((await bridgeContract.gasBridge()).config.minAmount).to.be.equal(newMinAmount);
        });

        it("Set max withdrawal amount", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const oldMaxAmount = ethers.parseEther("10000");
            expect((await bridgeContract.gasBridge()).config.maxAmount).to.be.equal(oldMaxAmount);
            const newMaxAmount = ethers.parseEther("5000");
            let tx = await bridgeContract.connect(governor).setMaxGasWithdrawalAmount(newMaxAmount);
            await expect(tx).to.emit(bridgeContract, "MaxGasWithdrawalChange").withArgs(newMaxAmount);
            expect((await bridgeContract.gasBridge()).config.maxAmount).to.be.equal(newMaxAmount);
            const newMaxAount2 = ethers.parseEther("10000");
            tx = await bridgeContract.connect(governor).setMaxGasWithdrawalAmount(newMaxAount2);
            await expect(tx).to.emit(bridgeContract, "MaxGasWithdrawalChange").withArgs(newMaxAount2);
            expect((await bridgeContract.gasBridge()).config.maxAmount).to.be.equal(newMaxAount2);
        });

        it("Set invalid min and max withdrawal amounts", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const fraction = ethers.parseEther("0.00000001");
            const minWithdrawalAmount = (await bridgeContract.gasBridge()).config.minAmount;
            const lowerThanMinWithdrawalAmount = minWithdrawalAmount - fraction;
            const maxWithdrawalAmount = (await bridgeContract.gasBridge()).config.maxAmount;
            const higherThanMaxWithdrawalAmount = maxWithdrawalAmount + fraction;

            // min amount must not be greater than max amount
            let tx = bridgeContract.connect(governor).setMinGasWithdrawalAmount(higherThanMaxWithdrawalAmount);
            await expect(tx).to.be.revertedWithCustomError(bridgeContract, "InvalidAmount");
            // min amount must not be greater than or equal to max amount
            tx = bridgeContract.connect(governor).setMinGasWithdrawalAmount(maxWithdrawalAmount);
            await expect(tx).to.be.revertedWithCustomError(bridgeContract, "InvalidAmount");
            // min amount must have maximal 8 non-zero digits
            tx = bridgeContract.connect(governor).setMinGasWithdrawalAmount(1000000000n);
            await expect(tx).to.be.revertedWithCustomError(bridgeContract, "InvalidAmount");

            // max amount must not be less than min amount
            tx = bridgeContract.connect(governor).setMaxGasWithdrawalAmount(lowerThanMinWithdrawalAmount);
            await expect(tx).to.be.revertedWithCustomError(bridgeContract, "InvalidAmount");
            // max amount must not be less than or equal to min amount
            tx = bridgeContract.connect(governor).setMaxGasWithdrawalAmount(minWithdrawalAmount);
            await expect(tx).to.be.revertedWithCustomError(bridgeContract, "InvalidAmount");
            // max amount must have maximal 8 non-zero digits
            tx = bridgeContract.connect(governor).setMaxGasWithdrawalAmount(1000000000n);
            await expect(tx).to.be.revertedWithCustomError(bridgeContract, "InvalidAmount");
        });

        it("Set max deposits per distribution", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const maxDepositsPerDistribution = (await bridgeContract.gasBridge()).config.maxDeposits;
            const newMaxDeposits = 10;
            expect(maxDepositsPerDistribution).not.to.be.equal(newMaxDeposits);
            const tx = bridgeContract.connect(governor).setMaxGasDeposits(newMaxDeposits);
            await expect(tx).to.emit(bridgeContract, "MaxGasDepositsChange").withArgs(newMaxDeposits);
            expect((await bridgeContract.gasBridge()).config.maxDeposits).to.be.equal(newMaxDeposits);
        });

        it("Fail setting max deposits per distribution to zero", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const maxDepositsPerDistribution = (await bridgeContract.gasBridge()).config.maxDeposits;
            await expect(maxDepositsPerDistribution).to.be.greaterThan(0);

            let tx = bridgeContract.connect(governor).setMaxGasDeposits(0);
            await expect(tx).to.be.revertedWithCustomError(bridgeContract, "InvalidAmount");
        });
    });

    describe("Funding the bridge", function () {
        it("Fund the bridge contract", async function () {
            const { bridgeContract, funder } = await loadFixture(deployBridgeFixture);
            const bridgeContractBalance = await ethers.provider.getBalance(bridgeContract.target);
            const funderBalance = await ethers.provider.getBalance(funder.address);
            expect(bridgeContractBalance).to.be.equal(ethers.parseEther("80.0"));
            const tx = await funder.sendTransaction({ to: bridgeContract.target, value: ethers.parseEther("20.0") });
            expect(tx).to.changeEtherBalances([funder, bridgeContract], [-ethers.parseEther("20.0"), ethers.parseEther("20.0")]);
            expect(tx).to.emit(bridgeContract, "Fund").withArgs(ethers.parseEther("20.0"));
        });

        it("Not funder fails to fund the bridge contract", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const bridgeContractBalance = await ethers.provider.getBalance(bridgeContract.target);
            expect(bridgeContractBalance).to.be.equal(ethers.parseEther("80.0"));
            let tx = governor.sendTransaction({ to: bridgeContract.target, value: ethers.parseEther("20.0") });
            await expect(tx).to.be.revertedWith("not funder");
        });

        it("Can fund after set as funder", async function () {
            const { bridgeContract, bridgeManagementContract, validator1, managementOwner } = await loadFixture(deployBridgeFixture);
            const bridgeContractBalance = await ethers.provider.getBalance(bridgeContract.target);
            expect(bridgeContractBalance).to.be.equal(ethers.parseEther("80.0"));
            const validator1Addr = await validator1.getAddress();
            const deployerBalance = await ethers.provider.getBalance(validator1Addr);
            expect(deployerBalance).to.be.greaterThan(ethers.parseEther("20.0"));

            const fundAmount = ethers.parseEther("10.0");
            const failTx = validator1.sendTransaction({ to: bridgeContract.target, value: fundAmount });
            await expect(failTx).to.be.revertedWith("not funder");

            const funderBefore = await bridgeManagementContract.getFunder();
            await expect(funderBefore).to.be.not.equal(validator1Addr);

            const tx = await bridgeManagementContract.connect(managementOwner).setFunder(validator1Addr);
            await expect(tx).to.emit(bridgeManagementContract, "FunderChange").withArgs(validator1Addr);

            await expect(await bridgeManagementContract.getFunder()).to.be.equal(validator1Addr);
            const fundTx = await validator1.sendTransaction({ to: bridgeContract.target, value: fundAmount });
            expect(fundTx).to.changeEtherBalances([validator1, bridgeContract], [-ethers.parseEther("10.0"), ethers.parseEther("10.0")]);
            expect(fundTx).to.emit(bridgeContract, "Fund").withArgs(ethers.parseEther("10.0"));
        });
    });

    describe("Deposit", async function () {
        it("Deposit the first Nonce", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const nonce = 1;
            const to = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
            const amount = 100000000n;

            const hashDepositData1 = await hashDepositOrWithdrawal(nonce, to, amount);
            // Raw deposit hash and root from deposit computed on Neo N3 bridge contract
            expect(hashDepositData1).to.be.equal("0x20aad97e2860b1934184ffb2b04ea45d49af5145fa43cb212027f9e8e728baea");
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            expect(root1).to.be.equal("0xdda77cac690580c1e5220d377cd807b4d2ed89751e4078525ee54297182d3d88");

            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).depositGas(root1, signatures, [Depositdata1]);
            await expect(tx).to.changeEtherBalances([bridgeContract, Depositdata1.to], [-toEthDecimals(Depositdata1.amount), toEthDecimals(Depositdata1.amount)]);
        });

        it("Deposit with Multiple Continous Nonce", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const nonce1 = 1;
            const to1 = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
            const amount1 = 100000000n;
            const nonce2 = 2;
            const to2 = "0x89FC6B042b146F373CeC4CA4A1b112697763360f";
            const amount2 = 100000000n;

            const hashDepositData1 = await hashDepositOrWithdrawal(nonce1, to1, amount1);
            expect(hashDepositData1).to.be.equal("0x20aad97e2860b1934184ffb2b04ea45d49af5145fa43cb212027f9e8e728baea");
            const hashDepositData2 = await hashDepositOrWithdrawal(nonce2, to2, amount2);
            expect(hashDepositData2).to.be.equal("0x983b3a1ee6b74a5ba07109966f86189d2adf108a25fd9b456030f684bffa8f84");
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            expect(root1).to.be.equal("0xdda77cac690580c1e5220d377cd807b4d2ed89751e4078525ee54297182d3d88");
            const new_root = await computeRoot(root1, hashDepositData2);
            expect(new_root).to.be.equal("0xa33a32b7b710705118b37d5fa7684a26e63840e7b5b88326177e7ec4ee7be253");
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).depositGas(new_root, signatures,
                [{ nonce: nonce1, to: to1, amount: amount1 }, { nonce: nonce2, to: to2, amount: amount2 }]);

            await expect(tx).to.changeEtherBalances([bridgeContract, to1, to2], [-toEthDecimals(amount1 + amount2), toEthDecimals(amount1), toEthDecimals(amount2)]);
            await expect(tx).to.emit(bridgeContract, "GasDeposit").withArgs(nonce1, to1, amount1);
            await expect(tx).to.emit(bridgeContract, "GasDeposit").withArgs(nonce2, to2, amount2);
            await expect(tx).to.emit(bridgeContract, "GasDepositRootUpdate").withArgs(nonce2, new_root);

            expect((await bridgeContract.gasBridge()).depositState.nonce).to.equal(nonce2);
            expect((await bridgeContract.gasBridge()).depositState.root).to.equal(new_root);
        });

        it("Deposit with Multiple Times with different Nonce Array", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.to, Depositdata1.amount);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures_first = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);
            await bridgeContract.connect(relayer).depositGas(root1, signatures_first, [Depositdata1]);

            //calculate the root and signatures for the second deposit
            const hashDepositData2 = await hashDepositOrWithdrawal(Depositdata2.nonce, Depositdata2.to, Depositdata2.amount);
            const hash12 = await computeRoot(root1, hashDepositData2);
            const hashDepositData3 = await hashDepositOrWithdrawal(Depositdata3.nonce, Depositdata3.to, Depositdata3.amount);
            const hash123 = await computeRoot(hash12, hashDepositData3);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [hash123]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).depositGas(hash123, signatures, [Depositdata2, Depositdata3]);

            await expect(tx).to.changeEtherBalances([bridgeContract, Depositdata2.to, Depositdata3.to], [-toEthDecimals(Depositdata2.amount + Depositdata3.amount), toEthDecimals(Depositdata2.amount), toEthDecimals(Depositdata3.amount)]);
            await expect(tx).to.emit(bridgeContract, "GasDeposit").withArgs(Depositdata2.nonce, Depositdata2.to, Depositdata2.amount);
            await expect(tx).to.emit(bridgeContract, "GasDeposit").withArgs(Depositdata3.nonce, Depositdata3.to, Depositdata3.amount);
            await expect(tx).to.emit(bridgeContract, "GasDepositRootUpdate").withArgs(Depositdata3.nonce, hash123);

            expect((await bridgeContract.gasBridge()).depositState.nonce).to.equal(Depositdata3.nonce);
            expect((await bridgeContract.gasBridge()).depositState.root).to.equal(hash123);
        });

        it("Bridge two deposits with insufficient funds for executing the first deposit", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const bridgeContractBalance = await ethers.provider.getBalance(bridgeContract.target);

            const depositData = { to: validator1, amount: 10000000001n, nonce: 1 };
            expect(toEthDecimals(depositData.amount)).to.be.greaterThan(bridgeContractBalance);
            expect(toEthDecimals(Depositdata2.amount)).to.be.lessThanOrEqual(bridgeContractBalance);

            const hashDepositData1 = await hashDepositOrWithdrawal(depositData.nonce, depositData.to, depositData.amount);
            const hashDepositData2 = await hashDepositOrWithdrawal(Depositdata2.nonce, Depositdata2.to, Depositdata2.amount);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_root = await computeRoot(root1, hashDepositData2);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).depositGas(new_root, signatures, [depositData, Depositdata2]);
            // check the balance is not change for the recipient address; but the root and depositNonce are both updated
            await expect(tx).to.changeEtherBalances([bridgeContract, depositData.to, Depositdata2.to], [-toEthDecimals(Depositdata2.amount), 0, toEthDecimals(Depositdata2.amount)]);

            expect((await bridgeContract.gasBridge()).depositState.nonce).to.equal(Depositdata2.nonce);
            expect((await bridgeContract.gasBridge()).depositState.root).to.equal(new_root);

            let claimable1 = await bridgeContract.claimableGas(depositData.nonce);
            // Deposit 1 was added to the claimable mapping
            expect(claimable1.to).to.equal(depositData.to);
            expect(claimable1.amount).to.equal(depositData.amount);

            let claimable2 = await bridgeContract.claimableGas(Depositdata2.nonce);
            // Deposit 2 could be paid and was not added to the claimable mapping
            expect(claimable2.to).to.equal("0x0000000000000000000000000000000000000000");
            expect(claimable2.amount).to.equal(0);

            await expect(tx).to.emit(bridgeContract, "GasClaimable").withArgs(depositData.nonce, depositData.to, depositData.amount);
        });

        it("Bridge three deposits with insufficient funds for executing the second deposit", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const bridgeContractBalance = await ethers.provider.getBalance(bridgeContract.target);

            const depositData1 = { to: validator2, amount: 12n, nonce: 1 };
            const depositData2 = { to: validator1, amount: 10000000001n, nonce: 2 };
            const depositData3 = { to: validator3, amount: 13n, nonce: 3 };
            expect(toEthDecimals(Depositdata1.amount)).to.be.lessThanOrEqual(bridgeContractBalance);
            expect(toEthDecimals(depositData2.amount)).to.be.greaterThan(bridgeContractBalance);
            expect(toEthDecimals(Depositdata3.amount)).to.be.lessThanOrEqual(bridgeContractBalance);

            const hashDepositData1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.to, depositData1.amount);
            const hashDepositData2 = await hashDepositOrWithdrawal(depositData2.nonce, depositData2.to, depositData2.amount);
            const hashDepositData3 = await hashDepositOrWithdrawal(depositData3.nonce, depositData3.to, depositData3.amount);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const root2 = await computeRoot(root1, hashDepositData2);
            const new_root = await computeRoot(root2, hashDepositData3);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).depositGas(new_root, signatures, [depositData1, depositData2, depositData3]);
            // check the balance is not change for the recipient address; but the root and depositNonce are both updated
            await expect(tx).to.changeEtherBalances([bridgeContract, depositData1.to, depositData2.to, depositData3.to], [-toEthDecimals(depositData1.amount) - toEthDecimals(depositData3.amount), toEthDecimals(depositData1.amount), 0, toEthDecimals(depositData3.amount)]);

            expect((await bridgeContract.gasBridge()).depositState.nonce).to.equal(depositData3.nonce);
            expect((await bridgeContract.gasBridge()).depositState.root).to.equal(new_root);

            let claimable1 = await bridgeContract.claimableGas(depositData1.nonce);
            // Deposit 1 was added to the claimable mapping
            expect(claimable1.to).to.equal("0x0000000000000000000000000000000000000000");
            expect(claimable1.amount).to.equal(0);

            let claimable2 = await bridgeContract.claimableGas(depositData2.nonce);
            // Deposit 2 could be paid and was not added to the claimable mapping
            expect(claimable2.to).to.equal(depositData2.to);
            expect(claimable2.amount).to.equal(depositData2.amount);

            let claimable3 = await bridgeContract.claimableGas(depositData3.nonce);
            // Deposit 2 could be paid and was not added to the claimable mapping
            expect(claimable3.to).to.equal("0x0000000000000000000000000000000000000000");
            expect(claimable3.amount).to.equal(0);

            await expect(tx).to.emit(bridgeContract, "GasClaimable").withArgs(depositData2.nonce, depositData2.to, depositData2.amount);
        });

        it("Deposit When Recipient is Contract", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const data2 = { nonce: 2, amount: 200000000n, to: await bridgeContract.getAddress() };

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.to, Depositdata1.amount);
            const hashDepositData2 = await hashDepositOrWithdrawal(data2.nonce, data2.to, data2.amount);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_root = await computeRoot(root1, hashDepositData2);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).depositGas(new_root, signatures, [Depositdata1, data2]);

            await expect(tx).to.changeEtherBalances([bridgeContract, Depositdata1.to], [-toEthDecimals(Depositdata1.amount), toEthDecimals(Depositdata1.amount)]);
            expect((await bridgeContract.gasBridge()).depositState.nonce).to.equal(data2.nonce);
            expect((await bridgeContract.gasBridge()).depositState.root).to.equal(new_root);
            //check claim table change
            let claimable1 = await bridgeContract.claimableGas(Depositdata1.nonce);
            expect(claimable1.to).to.equal(ethers.ZeroAddress);
            expect(claimable1.amount).to.equal(0);
            let claimable2 = await bridgeContract.claimableGas(Depositdata2.nonce);
            expect(claimable2.to).to.equal(data2.to);
            expect(claimable2.amount).to.equal(data2.amount);
        });

        it("Deposit When Deposit Length is Equal to 10", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const dataArray = [];
            const nrDeposits = 10;
            let hashResult = ethers.ZeroHash;
            for (let i = 0; i < nrDeposits; i++) {
                dataArray.push({ nonce: i + 1, amount: 100000000n, to: relayer.address });
                hashResult = await computeRoot(hashResult, await hashDepositOrWithdrawal(dataArray[i].nonce, dataArray[i].to, dataArray[i].amount));
            }
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [hashResult]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).depositGas(hashResult, signatures, dataArray);
            await expect(tx).to.changeEtherBalances([bridgeContract, relayer.address], [-toEthDecimals(dataArray[0].amount * BigInt(nrDeposits)), toEthDecimals(dataArray[0].amount * BigInt(nrDeposits))]);
            let depositState = (await bridgeContract.gasBridge()).depositState;
            expect(depositState.nonce).to.equal(10);
            expect(depositState.root).to.equal(hashResult);
            for (let i = 0; i < nrDeposits; i++) {
                await expect(tx).to.emit(bridgeContract, "GasDeposit").withArgs(dataArray[i].nonce, dataArray[i].to, dataArray[i].amount);
            }
            await expect(tx).to.emit(bridgeContract, "GasDepositRootUpdate").withArgs(dataArray[nrDeposits - 1].nonce, hashResult);
        });

        // Depositing to the zero address is disallowed on the source chain, but the bridge contract should handle it as a normal deposit if it were to be allowed.
        it("Deposit When Recipient Address is Zero Address", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const data_withZeroAddress = { nonce: 1, amount: 100000000n, to: ethers.ZeroAddress };
            const root = await computeRoot(ethers.ZeroHash, await hashDepositOrWithdrawal(data_withZeroAddress.nonce, data_withZeroAddress.to, data_withZeroAddress.amount));

            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).depositGas(root, signatures, [data_withZeroAddress]);
            await expect(tx).to.changeEtherBalances([bridgeContract, ethers.ZeroAddress], [-toEthDecimals(data_withZeroAddress.amount), toEthDecimals(data_withZeroAddress.amount)]);
            let depositState = (await bridgeContract.gasBridge()).depositState;
            expect(depositState.nonce).to.equal(1);
            expect(depositState.root).to.equal(root);
            await expect(tx).to.emit(bridgeContract, "GasDeposit").withArgs(data_withZeroAddress.nonce, data_withZeroAddress.to, data_withZeroAddress.amount);
            await expect(tx).to.emit(bridgeContract, "GasDepositRootUpdate").withArgs(data_withZeroAddress.nonce, root);
        });

        it("Should revert with no deposits", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await expect(bridgeContract.connect(relayer).depositGas(ethers.ZeroHash, [], [])).to.be.revertedWithCustomError(bridgeContract, "InvalidDepositsLength");
        });

        it("Should revert when providing too many deposits in single transaction", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const dataArray = [];
            let hashResult = ethers.ZeroHash;
            for (let i = 0; i < 101; i++) {
                dataArray.push({ nonce: i + 1, amount: 100000000n, to: relayer.address });
                hashResult = await computeRoot(hashResult, await hashDepositOrWithdrawal(dataArray[i].nonce, dataArray[i].to, dataArray[i].amount));
            }
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [hashResult]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            await expect(bridgeContract.connect(relayer).depositGas(hashResult, signatures, dataArray)).to.be.revertedWithCustomError(bridgeContract, "InvalidDepositsLength");
        });

        it("Should revert with the wrong first nonce", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await expect(bridgeContract.connect(relayer).depositGas(ethers.ZeroHash, [], [Depositdata2])).to.be.revertedWithCustomError(bridgeContract, "InvalidNonceSequence");
        });

        it("Should revert when nonce is not subsequent", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await expect(bridgeContract.connect(relayer).depositGas(ethers.ZeroHash, [], [Depositdata1, Depositdata3])).to.be.revertedWithCustomError(bridgeContract, "InvalidNonceSequence");
        });

        it("Should revert when signature length less than 5", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.to, Depositdata1.amount);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [0, 2, 3, 4]);

            await expect(bridgeContract.connect(relayer).depositGas(root1, signatures, [Depositdata1])).to.be.revertedWithCustomError(bridgeContract, "InvalidValidatorSignatures");
        });

        it("Should revert when signature length is 5 but with two duplicate signature", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.to, Depositdata1.amount);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 1, 3, 4, 5]);

            await expect(bridgeContract.connect(relayer).depositGas(root1, signatures, [Depositdata1])).to.be.revertedWithCustomError(bridgeContract, "InvalidValidatorSignatures")
        });

        it("Should revert when signature length is 5 but not with order", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.to, Depositdata1.amount);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 6, 5]);

            await expect(bridgeContract.connect(relayer).depositGas(root1, signatures, [Depositdata1])).to.be.revertedWithCustomError(bridgeContract, "InvalidValidatorSignatures");
        });

        it("Should revert when signature verify failed", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.to, Depositdata1.amount);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            //index 0 refers to relayer signer in the method getValidatorSignatures, thus there are only 4 validator signatures and the signature verification should fail.
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [0, 2, 3, 4, 5]);

            await expect(bridgeContract.connect(relayer).depositGas(root1, signatures, [Depositdata1])).to.be.revertedWithCustomError(bridgeContract, "InvalidValidatorSignatures");
        });

        it("Should revert when root is invalid", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.to, Depositdata1.amount);
            const root1 = await computeRoot(hashDepositData1, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            await expect(bridgeContract.connect(relayer).depositGas(root1, signatures, [Depositdata1])).to.be.revertedWithCustomError(bridgeContract, "InvalidRoot")
        });
    });

    describe("Withdraw", function () {
        it("withdraw only once", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const withdrawalAmount = ethers.parseEther("10");
            const withdrawalFee = (await bridgeContract.gasBridge()).config.fee;

            const withdrawData = { nonce: 1, amount: withdrawalAmount + withdrawalFee, to: relayer.address };
            const tx = await bridgeContract.connect(relayer).withdrawGas(withdrawData.to, withdrawalFee, { value: withdrawData.amount });

            const hashWithdrawData1 = await hashDepositOrWithdrawal(withdrawData.nonce, relayer.address, toNeoDecimals(withdrawalAmount));
            const new_withdrawRoot = await computeRoot(ethers.ZeroHash, hashWithdrawData1);

            let withdrawalState = (await bridgeContract.gasBridge()).withdrawalState;
            expect(withdrawalState.nonce).to.be.equal(1);
            expect(withdrawalState.root).to.be.equal(new_withdrawRoot);
            await expect(tx).to.emit(bridgeContract, "GasWithdrawal").withArgs(1, relayer.address, toNeoDecimals(withdrawalAmount), relayer.address, hashWithdrawData1, new_withdrawRoot);
        });

        it("withdraw multiple times", async function () {
            const { bridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            let withdrawalAmount_1 = ethers.parseEther("1");
            let withdrawalAmount_2 = ethers.parseEther("2");
            let withdrawalFee = (await bridgeContract.gasBridge()).config.fee;

            const withdrawData1 = { nonce: 1, amount: withdrawalAmount_1, to: relayer.address };
            await bridgeContract.connect(relayer).withdrawGas(withdrawData1.to, withdrawalFee, { value: withdrawalAmount_1 + withdrawalFee });
            const withdrawData2 = { nonce: 2, amount: withdrawalAmount_2, to: validator1.address };
            const tx2 = await bridgeContract.connect(relayer).withdrawGas(withdrawData2.to, withdrawalFee, { value: withdrawalAmount_2 + withdrawalFee });

            const hashWithdrawData1 = await hashDepositOrWithdrawal(withdrawData1.nonce, relayer.address, toNeoDecimals(withdrawData1.amount));
            const hash1 = await computeRoot(ethers.ZeroHash, hashWithdrawData1);
            const hashWithdrawData2 = await hashDepositOrWithdrawal(withdrawData2.nonce, validator1.address, toNeoDecimals(withdrawData2.amount));
            const hash12 = await computeRoot(hash1, hashWithdrawData2);

            let withdrawalState = (await bridgeContract.gasBridge()).withdrawalState;
            expect(withdrawalState.nonce).to.be.equal(2);
            expect(withdrawalState.root).to.be.equal(hash12);
            await expect(tx2).to.emit(bridgeContract, "GasWithdrawal").withArgs(2, validator1.address, toNeoDecimals(withdrawData2.amount), relayer.address, hashWithdrawData2, hash12);
        });

        it("withdraw with amount edge case", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            let gasBridge = (await bridgeContract.gasBridge());
            const minWithdrawalAmount = gasBridge.config.minAmount;
            const withdrawalFee = gasBridge.config.fee;
            const minWithdrawalAmountWithFee = minWithdrawalAmount + withdrawalFee;

            const withdrawData = { nonce: 1, amount: minWithdrawalAmount, to: relayer.address };
            const minTx = await bridgeContract.connect(relayer).withdrawGas(withdrawData.to, withdrawalFee, { value: minWithdrawalAmountWithFee });

            const hashWithdrawData1 = await hashDepositOrWithdrawal(withdrawData.nonce, relayer.address, toNeoDecimals(minWithdrawalAmount));
            const new_withdrawRoot = await computeRoot(ethers.ZeroHash, hashWithdrawData1);

            let withdrawalState = (await bridgeContract.gasBridge()).withdrawalState;
            expect(withdrawalState.nonce).to.be.equal(1);
            expect(withdrawalState.root).to.be.equal(new_withdrawRoot);
            await expect(minTx).to.emit(bridgeContract, "GasWithdrawal").withArgs(1, relayer.address, toNeoDecimals(withdrawData.amount), relayer.address, hashWithdrawData1, new_withdrawRoot);
            await expect(minTx).to.changeEtherBalances([bridgeContract, relayer], [minWithdrawalAmountWithFee, -minWithdrawalAmountWithFee]);
        });

        it("withdraw with the wrong amount", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const invalidAmount = ethers.parseEther("2.000000001");
            let config = (await bridgeContract.gasBridge()).config;
            const minWithdrawalAmount = config.minAmount;
            const maxWithdrawalAmount = config.maxAmount;
            const withdrawalFee = config.fee;
            await expect(invalidAmount).to.be.greaterThanOrEqual(minWithdrawalAmount + withdrawalFee);
            await expect(invalidAmount).to.be.lessThanOrEqual(maxWithdrawalAmount + withdrawalFee);
            await expect(bridgeContract.connect(relayer).withdrawGas(relayer, withdrawalFee, { value: invalidAmount })).to.be.revertedWithCustomError(bridgeContract, "InvalidAmount");
        });

        it("withdraw is too low", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const minFraction = ethers.parseEther("0.00000001");
            let config = (await bridgeContract.gasBridge()).config;
            const minWithdrawalAmount = config.minAmount;
            const withdrawalFee = config.fee;
            const tooLowWithdrawalAmount = minWithdrawalAmount + withdrawalFee - minFraction;
            await expect(bridgeContract.connect(relayer).withdrawGas(relayer, withdrawalFee, { value: tooLowWithdrawalAmount })).to.be.revertedWithCustomError(bridgeContract, "AmountBelowMinAmount");
        });

        it("withdraw is too high", async function () {
            const { bridgeContract, validator6, validator7 } = await loadFixture(deployBridgeFixture);
            validator6.sendTransaction({ to: validator7, value: ethers.parseEther("1000") }); // make sure validator7 has a high enough balance
            const minFraction = ethers.parseEther("0.00000001");
            let config = (await bridgeContract.gasBridge()).config;
            const maxWithdrawalAmount = config.maxAmount;
            const withdrawalFee = config.fee;
            const tooHighWithdrawalAmount = maxWithdrawalAmount + withdrawalFee + minFraction;
            await expect(bridgeContract.connect(validator7).withdrawGas(validator6, withdrawalFee, { value: tooHighWithdrawalAmount })).to.be.revertedWithCustomError(bridgeContract, "AmountExceedsMaxAmount");
            validator7.sendTransaction({ to: validator6, value: ethers.parseEther("1000") });
        });

        it("Withdraw with different fees and verify unclaimed rewards", async function () {
            const { bridgeContract, relayer, funder, governor } = await loadFixture(deployBridgeFixture);

            let withdrawalAmount_1 = ethers.parseEther("10");
            let withdrawalAmount_2 = ethers.parseEther("20");
            let withdrawalFeeBeforeChange = (await bridgeContract.gasBridge()).config.fee;
            expect(withdrawalFeeBeforeChange).to.be.equal(ethers.parseEther("0.1"));
            expect(await bridgeContract.unclaimedRewards()).to.be.equal(0);

            const to1 = relayer.address;
            await bridgeContract.connect(relayer).withdrawGas(to1, withdrawalFeeBeforeChange, { value: withdrawalAmount_1 });

            await bridgeContract.connect(governor).setGasWithdrawalFee(ethers.parseEther("0.5"));
            const withdrawalFeeAfterChange = (await bridgeContract.gasBridge()).config.fee;
            expect(withdrawalFeeAfterChange).to.be.equal(ethers.parseEther("0.5"));

            const to2 = funder.address;
            const tx2 = await bridgeContract.connect(relayer).withdrawGas(to2, withdrawalFeeAfterChange, { value: withdrawalAmount_2 });

            let withdrawalState = (await bridgeContract.gasBridge()).withdrawalState;
            expect(withdrawalState.nonce).to.be.equal(2);
            expect(await bridgeContract.unclaimedRewards()).to.be.equal(withdrawalFeeBeforeChange + withdrawalFeeAfterChange);
        });
    });

    describe("Claim", function () {
        it("Claim successful for EOA account", async function () {
            const { bridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const depositData = { to: validator1.address, amount: 8000000001n, nonce: 1 };
            expect(await ethers.provider.getBalance(bridgeContract.target)).to.be.lessThan(toEthDecimals(depositData.amount));

            const hashDepositData1 = await hashDepositOrWithdrawal(depositData.nonce, depositData.to, depositData.amount);
            const new_root = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const depositTx = await bridgeContract.connect(relayer).depositGas(new_root, signatures, [depositData]);

            await expect(depositTx).to.changeEtherBalances([bridgeContract, Depositdata1.to], [0, 0]);

            let gasBridge = await bridgeContract.gasBridge();
            let depositState = gasBridge.depositState;
            let withdrawalFee = gasBridge.config.fee;
            expect(depositState.nonce).to.equal(depositData.nonce);
            expect(depositState.root).to.equal(new_root);

            let claimable = await bridgeContract.claimableGas(depositData.nonce);
            expect(claimable.to).to.equal(depositData.to);
            expect(claimable.amount).to.equal(depositData.amount);
            await expect(depositTx).to.emit(bridgeContract, "GasClaimable").withArgs(depositData.nonce, depositData.to, depositData.amount);

            // Let's withdraw some eth to increase the contract's balance and make the claim possible.
            const amount = ethers.parseEther("10");
            const withdrawTx = await bridgeContract.connect(relayer).withdrawGas(relayer.address, withdrawalFee, { value: amount });
            await expect(withdrawTx).to.changeEtherBalances([bridgeContract, relayer.address], [amount, -amount]);
            const bridgeContractBalance = await ethers.provider.getBalance(bridgeContract.target);
            expect(bridgeContractBalance).to.be.greaterThanOrEqual((await bridgeContract.claimableGas(depositData.nonce)).amount);

            const claim_tx1 = await bridgeContract.connect(validator1).claimGas(depositData.nonce);

            claimable = await bridgeContract.claimableGas(depositData.nonce);
            expect(claimable.to).to.equal(ethers.ZeroAddress);
            expect(claimable.amount).to.equal(0);
            await expect(claim_tx1).to.emit(bridgeContract, "GasClaim").withArgs(depositData.nonce, depositData.to, depositData.amount);
            await expect(claim_tx1).to.changeEtherBalances([bridgeContract, depositData.to], [-toEthDecimals(depositData.amount), toEthDecimals(depositData.amount)]);
        });

        it("Claim successful for payable contract", async function () {
            const { bridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const testpayableContract = await ethers.deployContract("TestPayableContract");
            await testpayableContract.waitForDeployment();

            const data1 = { nonce: 1, amount: 10000000n, to: await testpayableContract.getAddress() };
            const hashDepositData1 = await hashDepositOrWithdrawal(data1.nonce, data1.to, data1.amount);
            const new_root = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).depositGas(new_root, signatures, [data1]);

            await expect(tx).to.changeEtherBalances([bridgeContract, data1.to], [0, 0]);
            let depositState = (await bridgeContract.gasBridge()).depositState;
            expect(depositState.nonce).to.equal(data1.nonce);
            expect(depositState.root).to.equal(new_root);

            let claimable = await bridgeContract.claimableGas(data1.nonce);
            expect(claimable.to).to.equal(data1.to);
            expect(claimable.amount).to.equal(data1.amount);
            await expect(tx).to.emit(bridgeContract, "GasClaimable").withArgs(data1.nonce, data1.to, data1.amount);

            const tx2 = await bridgeContract.connect(validator1).claimGas(data1.nonce);

            claimable = await bridgeContract.claimableGas(data1.nonce);
            expect(claimable.to).to.equal(ethers.ZeroAddress);
            expect(claimable.amount).to.equal(0);
            await expect(tx2).to.emit(bridgeContract, "GasClaim").withArgs(data1.nonce, data1.to, data1.amount);
            await expect(tx2).to.changeEtherBalances([bridgeContract, data1.to], [-toEthDecimals(data1.amount), toEthDecimals(data1.amount)]);

            await expect(bridgeContract.connect(relayer).claimGas(data1.nonce)).to.be.revertedWithCustomError(bridgeContract, "NonexistentClaimable")
        });

        it("Fail to claim due to Contract not payable", async function () {
            const { bridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const data1 = { nonce: 1, amount: 100000000n, to: await bridgeContract.getAddress() };
            const hashDepositData1 = await hashDepositOrWithdrawal(data1.nonce, data1.to, data1.amount);
            const new_root = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).depositGas(new_root, signatures, [data1]);

            await expect(tx).to.changeEtherBalances([bridgeContract, data1.to], [0, 0]);
            let depositState = (await bridgeContract.gasBridge()).depositState;
            expect(depositState.nonce).to.equal(data1.nonce);
            expect(depositState.root).to.equal(new_root);

            let claimable = await bridgeContract.claimableGas(Depositdata1.nonce);
            expect(claimable.to).to.equal(data1.to);
            expect(claimable.amount).to.equal(data1.amount);
            await expect(tx).to.emit(bridgeContract, "GasClaimable").withArgs(data1.nonce, data1.to, data1.amount);

            await expect(bridgeContract.connect(validator1).claimGas(data1.nonce)).to.be.revertedWithCustomError(bridgeContract, "TransferFailed");
        });

        it("Fail to claim for not existed nonce in the claim table", async function () {
            const { bridgeContract, validator1 } = await loadFixture(deployBridgeFixture);
            await expect(bridgeContract.connect(validator1).claimGas(3)).to.be.revertedWithCustomError(bridgeContract, "NonexistentClaimable");
        });
    });

    describe("Lock Function", async function () {
        it("Lock with SecurityGuard Account and Unlock with Governor", async function () {
            const { bridgeContract, validator1, governor, securityGuard } = await loadFixture(deployBridgeFixture);

            await bridgeContract.connect(securityGuard).pauseBridge();
            expect(await bridgeContract.bridgePaused()).to.equal(true);

            // unlock with the governor
            await expect(bridgeContract.connect(validator1).unpauseBridge()).to.be.revertedWith("not governor");
            await bridgeContract.connect(governor).unpauseBridge();
            expect(await bridgeContract.bridgePaused()).to.equal(false);
        });

        it("Cannot unlock contract if it's already unlocked", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            await expect(bridgeContract.connect(governor).unpauseBridge()).to.be.revertedWithCustomError(bridgeContract, "BridgeUnpaused");
        });

        it("Cannot lock contract if it's locked", async function () {
            const { bridgeContract, securityGuard } = await loadFixture(deployBridgeFixture);
            await expect(bridgeContract.connect(securityGuard).pauseBridge()).to.emit(bridgeContract, "BridgePause");
            await expect(bridgeContract.connect(securityGuard).pauseBridge()).to.be.revertedWithCustomError(bridgeContract, "BridgePaused");
        });

        it("Cannot deposit, claim or withdraw Gas if contract is locked", async function () {
            const { bridgeContract, relayer, securityGuard } = await loadFixture(deployBridgeFixture);
            await bridgeContract.connect(securityGuard).pauseBridge()

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.to, Depositdata1.amount);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);
            await expect(bridgeContract.connect(relayer).depositGas(root1, signatures, [Depositdata1])).to.be.revertedWithCustomError(bridgeContract, "BridgePaused");
            await expect(bridgeContract.connect(relayer).claimGas(Depositdata1.nonce)).to.be.revertedWithCustomError(bridgeContract, "BridgePaused");
            const withdrawData = { nonce: 1, amount: ethers.parseEther("1"), to: relayer.address };
            let withdrawalFee = (await bridgeContract.gasBridge()).config.fee;
            await expect(bridgeContract.connect(relayer).withdrawGas(withdrawData.to, withdrawalFee, { value: withdrawData.amount })).to.be.revertedWithCustomError(bridgeContract, "BridgePaused");
            await expect(bridgeContract.connect(securityGuard).pauseBridge()).to.be.revertedWithCustomError(bridgeContract, "BridgePaused");
        });
    });
});

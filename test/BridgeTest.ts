import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { getContractAddress } from "@ethersproject/address";
import { getValidatorSignatures } from "../utils/signature-utils";
import {
    to1, to2, to3, to4, to5, to6, to7, to8, to9, to0,
    toEthDecimals, toNeoDecimals, hashDepositOrWithdrawal, computeRoot, validator1, validator2, validator3, validator7
} from "./helper";

const Depositdata1 = { to: validator1, amount: 100000000n, nonce: 1 };
const Depositdata2 = { to: validator2, amount: 200000000n, nonce: 2 };
const Depositdata3 = { to: validator3, amount: 300000000n, nonce: 3 };

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

        const BridgeManagementFactory = await ethers.getContractFactory("BridgeManagementImpl");
        const bridgeManagementContract = await BridgeManagementFactory.connect(deployer).deploy();

        const BridgeContract = await ethers.getContractFactory("BridgeImpl");
        const contractAddress = getContractAddress({
            from: deployer.address,
            nonce: await deployer.getNonce(),
        });
        // Fund the bridge contract's address before deployment.
        await funder.sendTransaction({ to: contractAddress, value: ethers.parseEther("100.0") });

        const bridgeContract = await BridgeContract.connect(deployer).deploy();
        await bridgeContract.waitForDeployment();

        return {
            bridgeContract,
            bridgeManagementContract,
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
            managementOwner
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
            await expect(tx).to.emit(bridgeContract, "WithdrawalFeeChanged").withArgs(newFee);
            gasBridge = await bridgeContract.gasBridge()
            expect(gasBridge.config.fee).to.be.equal(newFee);
        });

        it("Set min withdrawal amount", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const oldMinAmount = ethers.parseEther("1");
            expect((await bridgeContract.gasBridge()).config.minAmount).to.be.equal(oldMinAmount);
            const newMinAmount = ethers.parseEther("0.2");
            const tx = await bridgeContract.connect(governor).setGasWithdrawalMinAmount(newMinAmount);
            await expect(tx).to.emit(bridgeContract, "MinWithdrawalAmountChanged").withArgs(newMinAmount);
            expect((await bridgeContract.gasBridge()).config.minAmount).to.be.equal(newMinAmount);
        });

        it("Set max withdrawal amount", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const oldMaxAmount = ethers.parseEther("10000");
            expect((await bridgeContract.gasBridge()).config.maxAmount).to.be.equal(oldMaxAmount);
            const newMaxAmount = ethers.parseEther("5000");
            let tx = await bridgeContract.connect(governor).setGasWithdrawalMaxAmount(newMaxAmount);
            await expect(tx).to.emit(bridgeContract, "MaxWithdrawalAmountChanged").withArgs(newMaxAmount);
            expect((await bridgeContract.gasBridge()).config.maxAmount).to.be.equal(newMaxAmount);
            const newMaxAount2 = ethers.parseEther("10000");
            tx = await bridgeContract.connect(governor).setGasWithdrawalMaxAmount(newMaxAount2);
            await expect(tx).to.emit(bridgeContract, "MaxWithdrawalAmountChanged").withArgs(newMaxAount2);
            expect((await bridgeContract.gasBridge()).config.maxAmount).to.be.equal(newMaxAount2);
        });

        it("Set invalid min and max withdrawal amounts", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const fraction = ethers.parseEther("0.00000001");
            const minWithdrawalAmount = (await bridgeContract.gasBridge()).config.minAmount;
            const lowerThanMinWithdrawalAmount = minWithdrawalAmount - fraction;
            const maxWithdrawalAmount = (await bridgeContract.gasBridge()).config.maxAmount;
            const higherThanMaxWithdrawalAmount = maxWithdrawalAmount + fraction;

            let tx = bridgeContract.connect(governor).setGasWithdrawalMinAmount(higherThanMaxWithdrawalAmount);
            await expect(tx).to.be.revertedWith("Amount must be less than the maximal withdrawal amount");
            tx = bridgeContract.connect(governor).setGasWithdrawalMinAmount(maxWithdrawalAmount);
            await expect(tx).to.be.revertedWith("Amount must be less than the maximal withdrawal amount");
            tx = bridgeContract.connect(governor).setGasWithdrawalMinAmount(1000000000n);
            await expect(tx).to.be.revertedWith("Amount must have maximally 8 non-zero decimals");

            tx = bridgeContract.connect(governor).setGasWithdrawalMaxAmount(lowerThanMinWithdrawalAmount);
            await expect(tx).to.be.revertedWith("Amount must be greater than the minimal withdrawal amount");
            tx = bridgeContract.connect(governor).setGasWithdrawalMaxAmount(minWithdrawalAmount);
            await expect(tx).to.be.revertedWith("Amount must be greater than the minimal withdrawal amount");
            tx = bridgeContract.connect(governor).setGasWithdrawalMaxAmount(1000000000n);
            await expect(tx).to.be.revertedWith("Amount must have maximally 8 non-zero decimals");
        });

        it("Set max deposits per distribution", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const maxDepositsPerDistribution = (await bridgeContract.gasBridge()).config.maxDepositsPerDistribution;
            const newMaxDepositsPerDistribution = 10;
            expect(maxDepositsPerDistribution).not.to.be.equal(newMaxDepositsPerDistribution);
            const tx = bridgeContract.connect(governor).setGasMaxNrDepositsPerDistribution(newMaxDepositsPerDistribution);
            await expect(tx).to.emit(bridgeContract, "MaxDepositsPerDistributionChanged").withArgs(newMaxDepositsPerDistribution);
            expect((await bridgeContract.gasBridge()).config.maxDepositsPerDistribution).to.be.equal(newMaxDepositsPerDistribution);
        });

        it("Fail setting max deposits per distribution to zero", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            const maxDepositsPerDistribution = (await bridgeContract.gasBridge()).config.maxDepositsPerDistribution;
            await expect(maxDepositsPerDistribution).to.be.greaterThan(0);

            let tx = bridgeContract.connect(governor).setGasMaxNrDepositsPerDistribution(0);
            await expect(tx).to.be.revertedWith("Value must be greater than 0");
        });
    });

    describe("Deposit", async function () {
        it("Deposit the first Nonce", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1]);
            await expect(tx).to.changeEtherBalances([bridgeContract, Depositdata1.to], [-toEthDecimals(Depositdata1.amount), toEthDecimals(Depositdata1.amount)]);
        });

        it("Deposit with Multiple Continous Nonce", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const hashDepositData2 = await hashDepositOrWithdrawal(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_root = await computeRoot(root1, hashDepositData2);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).deposit(new_root, signatures, [Depositdata1, Depositdata2]);

            await expect(tx).to.changeEtherBalances([bridgeContract, Depositdata1.to, Depositdata2.to], [-toEthDecimals(Depositdata1.amount + Depositdata2.amount), toEthDecimals(Depositdata1.amount), toEthDecimals(Depositdata2.amount)]);
            await expect(tx).to.emit(bridgeContract, "Deposit").withArgs(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            await expect(tx).to.emit(bridgeContract, "Deposit").withArgs(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);

            expect((await bridgeContract.gasBridge()).depositState.nonce).to.equal(Depositdata2.nonce);
            expect((await bridgeContract.gasBridge()).depositState.root).to.equal(new_root);
        });

        it("Deposit with Multiple Times with different Nonce Array", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures_first = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);
            await bridgeContract.connect(relayer).deposit(root1, signatures_first, [Depositdata1]);

            //calculate the root and signatures for the second deposit
            const hashDepositData2 = await hashDepositOrWithdrawal(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);
            const hash12 = await computeRoot(root1, hashDepositData2);
            const hashDepositData3 = await hashDepositOrWithdrawal(Depositdata3.nonce, Depositdata3.amount, Depositdata3.to);
            const hash123 = await computeRoot(hash12, hashDepositData3);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [hash123]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).deposit(hash123, signatures, [Depositdata2, Depositdata3]);

            await expect(tx).to.changeEtherBalances([bridgeContract, Depositdata2.to, Depositdata3.to], [-toEthDecimals(Depositdata2.amount + Depositdata3.amount), toEthDecimals(Depositdata2.amount), toEthDecimals(Depositdata3.amount)]);
            await expect(tx).to.emit(bridgeContract, "Deposit").withArgs(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);
            await expect(tx).to.emit(bridgeContract, "Deposit").withArgs(Depositdata3.nonce, Depositdata3.amount, Depositdata3.to);

            expect((await bridgeContract.gasBridge()).depositState.nonce).to.equal(Depositdata3.nonce);
            expect((await bridgeContract.gasBridge()).depositState.root).to.equal(hash123);
        });

        it("Bridge two deposits with insufficient funds for executing the first deposit", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const bridgeContractBalance = await ethers.provider.getBalance(bridgeContract.target);

            const depositData = { to: validator1, amount: 10000000001n, nonce: 1 };
            expect(toEthDecimals(depositData.amount)).to.be.greaterThan(bridgeContractBalance);
            expect(toEthDecimals(Depositdata2.amount)).to.be.lessThanOrEqual(bridgeContractBalance);

            const hashDepositData1 = await hashDepositOrWithdrawal(depositData.nonce, depositData.amount, depositData.to);
            const hashDepositData2 = await hashDepositOrWithdrawal(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_root = await computeRoot(root1, hashDepositData2);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).deposit(new_root, signatures, [depositData, Depositdata2]);
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

            await expect(tx).to.emit(bridgeContract, "Claimable").withArgs(depositData.nonce, depositData.amount, depositData.to);
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

            const hashDepositData1 = await hashDepositOrWithdrawal(depositData1.nonce, depositData1.amount, depositData1.to);
            const hashDepositData2 = await hashDepositOrWithdrawal(depositData2.nonce, depositData2.amount, depositData2.to);
            const hashDepositData3 = await hashDepositOrWithdrawal(depositData3.nonce, depositData3.amount, depositData3.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const root2 = await computeRoot(root1, hashDepositData2);
            const new_root = await computeRoot(root2, hashDepositData3);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).deposit(new_root, signatures, [depositData1, depositData2, depositData3]);
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

            await expect(tx).to.emit(bridgeContract, "Claimable").withArgs(depositData2.nonce, depositData2.amount, depositData2.to);
        });

        it("Deposit When Recipient is Contract", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const data2 = { nonce: 2, amount: 200000000n, to: await bridgeContract.getAddress() };

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const hashDepositData2 = await hashDepositOrWithdrawal(data2.nonce, data2.amount, data2.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_root = await computeRoot(root1, hashDepositData2);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).deposit(new_root, signatures, [Depositdata1, data2]);

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
            let hashResult = ethers.ZeroHash;
            for (let i = 0; i < 10; i++) {
                dataArray.push({ nonce: i + 1, amount: 100000000n, to: relayer.address });
                hashResult = await computeRoot(hashResult, await hashDepositOrWithdrawal(dataArray[i].nonce, dataArray[i].amount, dataArray[i].to));
            }
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [hashResult]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).deposit(hashResult, signatures, dataArray);
            await expect(tx).to.changeEtherBalances([bridgeContract, relayer.address], [-toEthDecimals(dataArray[0].amount * 10n), toEthDecimals(dataArray[0].amount * 10n)]);
            let depositState = (await bridgeContract.gasBridge()).depositState;
            expect(depositState.nonce).to.equal(10);
            expect(depositState.root).to.equal(hashResult);
            for (let i = 0; i < 10; i++) {
                await expect(tx).to.emit(bridgeContract, "Deposit").withArgs(dataArray[i].nonce, dataArray[i].amount, dataArray[i].to);
            }
        });

        //TODO: This needs to be discussed whether revert or not
        it("Deposit When Recipient Address is Zero Address", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const data_withZeroAddress = { nonce: 1, amount: 100000000n, to: ethers.ZeroAddress };
            const root = await computeRoot(ethers.ZeroHash, await hashDepositOrWithdrawal(data_withZeroAddress.nonce, data_withZeroAddress.amount, data_withZeroAddress.to));

            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).deposit(root, signatures, [data_withZeroAddress]);
            await expect(tx).to.changeEtherBalances([bridgeContract, ethers.ZeroAddress], [-toEthDecimals(data_withZeroAddress.amount), toEthDecimals(data_withZeroAddress.amount)]);
            let depositState = (await bridgeContract.gasBridge()).depositState;
            expect(depositState.nonce).to.equal(1);
            expect(depositState.root).to.equal(root);
            await expect(tx).to.emit(bridgeContract, "Deposit").withArgs(data_withZeroAddress.nonce, data_withZeroAddress.amount, data_withZeroAddress.to);
        });

        it("Should revert with empty proofs", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await expect(bridgeContract.connect(relayer).deposit(ethers.ZeroHash, [], [])).to.be.revertedWith("At least 1 deposit is required.");
        });

        it("Should revert when providing too many deposits in single transaction", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const dataArray = [];
            let hashResult = ethers.ZeroHash;
            for (let i = 0; i < 101; i++) {
                dataArray.push({ nonce: i + 1, amount: 100000000n, to: relayer.address });
                hashResult = await computeRoot(hashResult, await hashDepositOrWithdrawal(dataArray[i].nonce, dataArray[i].amount, dataArray[i].to));
            }
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [hashResult]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            await expect(bridgeContract.connect(relayer).deposit(hashResult, signatures, dataArray)).to.be.revertedWith("Too many deposits provided.");
        });

        it("Should revert with the wrong first nonce", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await expect(bridgeContract.connect(relayer).deposit(ethers.ZeroHash, [], [Depositdata2])).to.be.revertedWith("Only the next nonce is allowed in the first proof.");
        });

        it("Should revert when nonce is not subsequent", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await expect(bridgeContract.connect(relayer).deposit(ethers.ZeroHash, [], [Depositdata1, Depositdata3])).to.be.revertedWith("The nonces of the proofs must be subsequent.");
        });

        it("Should revert when signature length less than 5", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [0, 2, 3, 4]);

            await expect(bridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1])).to.be.revertedWith("Validator signature verification failed.");
        });

        it("Should revert when signature length is 5 but with two duplicate signature", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 1, 3, 4, 5]);

            await expect(bridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1])).to.be.revertedWith("Validator signature verification failed.");
        });

        it("Should revert when signature length is 5 but not with order", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 6, 5]);

            await expect(bridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1])).to.be.revertedWith("Validator signature verification failed.");
        });

        it("Should revert when signature verify failed", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            //index 0 refers to relayer signer in the method getValidatorSignatures, thus there are only 4 validator signatures and the signature verification should fail.
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [0, 2, 3, 4, 5]);

            await expect(bridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1])).to.be.revertedWith("Validator signature verification failed.");
        });

        it("Should revert when root is invalid", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(hashDepositData1, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            await expect(bridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1])).to.be.revertedWith("Deposits do not match the provided root.");
        });
    });

    describe("Withdraw", function () {
        it("withdraw only once", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const withdrawalAmount = ethers.parseEther("10");
            const withdrawalFee = (await bridgeContract.gasBridge()).config.fee;

            const withdrawData = { nonce: 1, amount: withdrawalAmount + withdrawalFee, to: relayer.address };
            const tx = await bridgeContract.connect(relayer).withdraw(withdrawData.to, { value: withdrawData.amount });

            const hashWithdrawData1 = await hashDepositOrWithdrawal(withdrawData.nonce, toNeoDecimals(withdrawalAmount), relayer.address);
            const new_withdrawRoot = await computeRoot(ethers.ZeroHash, hashWithdrawData1);

            let withdrawalState = (await bridgeContract.gasBridge()).withdrawalState;
            expect(withdrawalState.nonce).to.be.equal(1);
            expect(withdrawalState.root).to.be.equal(new_withdrawRoot);
            await expect(tx).to.emit(bridgeContract, "Withdrawal").withArgs(1, toNeoDecimals(withdrawalAmount), relayer.address, relayer.address, hashWithdrawData1, new_withdrawRoot);
        });

        it("withdraw multiple times", async function () {
            const { bridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            let withdrawalAmount_1 = ethers.parseEther("1");
            let withdrawalAmount_2 = ethers.parseEther("2");
            let withdrawalFee = (await bridgeContract.gasBridge()).config.fee;

            const withdrawData1 = { nonce: 1, amount: withdrawalAmount_1, to: relayer.address };
            await bridgeContract.connect(relayer).withdraw(withdrawData1.to, { value: withdrawalAmount_1 + withdrawalFee });
            const withdrawData2 = { nonce: 2, amount: withdrawalAmount_2, to: validator1.address };
            const tx2 = await bridgeContract.connect(relayer).withdraw(withdrawData2.to, { value: withdrawalAmount_2 + withdrawalFee });

            const hashWithdrawData1 = await hashDepositOrWithdrawal(withdrawData1.nonce, toNeoDecimals(withdrawData1.amount), relayer.address);
            const hash1 = await computeRoot(ethers.ZeroHash, hashWithdrawData1);
            const hashWithdrawData2 = await hashDepositOrWithdrawal(withdrawData2.nonce, toNeoDecimals(withdrawData2.amount), validator1.address);
            const hash12 = await computeRoot(hash1, hashWithdrawData2);

            let withdrawalState = (await bridgeContract.gasBridge()).withdrawalState;
            expect(withdrawalState.nonce).to.be.equal(2);
            expect(withdrawalState.root).to.be.equal(hash12);
            await expect(tx2).to.emit(bridgeContract, "Withdrawal").withArgs(2, toNeoDecimals(withdrawData2.amount), validator1.address, relayer.address, hashWithdrawData2, hash12);
        });

        it("withdraw with amount edge case", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            let gasBridge = (await bridgeContract.gasBridge());
            const withdrawalAmount = gasBridge.config.minAmount + ethers.parseEther("0.00000001");
            const withdrawalFee = gasBridge.config.fee;
            const withdrawalAmountWithFee = withdrawalAmount + withdrawalFee;

            const withdrawData = { nonce: 1, amount: withdrawalAmount, to: relayer.address };
            const tx = await bridgeContract.connect(relayer).withdraw(withdrawData.to, { value: withdrawalAmountWithFee });

            const hashWithdrawData1 = await hashDepositOrWithdrawal(withdrawData.nonce, toNeoDecimals(withdrawalAmount), relayer.address);
            const new_withdrawRoot = await computeRoot(ethers.ZeroHash, hashWithdrawData1);

            let withdrawalState = (await bridgeContract.gasBridge()).withdrawalState;
            expect(withdrawalState.nonce).to.be.equal(1);
            expect(withdrawalState.root).to.be.equal(new_withdrawRoot);
            await expect(tx).to.emit(bridgeContract, "Withdrawal").withArgs(1, toNeoDecimals(withdrawData.amount), relayer.address, relayer.address, hashWithdrawData1, new_withdrawRoot);
            await expect(tx).to.changeEtherBalances([bridgeContract, relayer], [withdrawalAmountWithFee, -withdrawalAmountWithFee]);
        });

        it("withdraw with the wrong amount", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const invalidAmount = ethers.parseEther("2.000000001");
            let config = (await bridgeContract.gasBridge()).config;
            const minWithdrawalAmount = config.minAmount;
            const maxWithdrawalAmount = config.maxAmount;
            const withdrawlFee = config.fee;
            await expect(invalidAmount).to.be.greaterThanOrEqual(minWithdrawalAmount + withdrawlFee);
            await expect(invalidAmount).to.be.lessThanOrEqual(maxWithdrawalAmount + withdrawlFee);
            await expect(bridgeContract.connect(relayer).withdraw(relayer, { value: invalidAmount })).to.be.revertedWith("Only amounts with maximally 8 non-zero decimals are allowed for withdrawals");
        });

        it("withdraw is too low", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const minFraction = ethers.parseEther("0.00000001");
            let config = (await bridgeContract.gasBridge()).config;
            const minWithdrawalAmount = config.minAmount;
            const withdrawlFee = config.fee;
            const tooLowWithdrawalAmount = minWithdrawalAmount + withdrawlFee - minFraction;
            await expect(bridgeContract.connect(relayer).withdraw(relayer, { value: tooLowWithdrawalAmount })).to.be.revertedWith("Withdrawal amount is too low");
        });

        it("withdraw is too high", async function () {
            const { bridgeContract, validator6, validator7 } = await loadFixture(deployBridgeFixture);
            validator6.sendTransaction({ to: validator7, value: ethers.parseEther("1000") }); // make sure validator7 has a high enough balance
            const minFraction = ethers.parseEther("0.00000001");
            let config = (await bridgeContract.gasBridge()).config;
            const maxWithdrawalAmount = config.maxAmount;
            const withdrawlFee = config.fee;
            const tooHighWithdrawalAmount = maxWithdrawalAmount + withdrawlFee + minFraction;
            await expect(bridgeContract.connect(validator7).withdraw(validator6, { value: tooHighWithdrawalAmount })).to.be.revertedWith("Withdrawal amount is too high");
            validator7.sendTransaction({ to: validator6, value: ethers.parseEther("1000") });
        });
    });

    describe("Claim", function () {
        it("Claim successful for EOA account", async function () {
            const { bridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const depositData = { to: validator1.address, amount: 10000000001n, nonce: 1 };

            const hashDepositData1 = await hashDepositOrWithdrawal(depositData.nonce, depositData.amount, depositData.to);
            const new_root = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const depositTx = await bridgeContract.connect(relayer).deposit(new_root, signatures, [depositData]);

            await expect(depositTx).to.changeEtherBalances([bridgeContract, Depositdata1.to], [0, 0]);

            let depositState = (await bridgeContract.gasBridge()).depositState;
            expect(depositState.nonce).to.equal(depositData.nonce);
            expect(depositState.root).to.equal(new_root);

            let claimable = await bridgeContract.claimableGas(depositData.nonce);
            expect(claimable.to).to.equal(depositData.to);
            expect(claimable.amount).to.equal(depositData.amount);
            await expect(depositTx).to.emit(bridgeContract, "Claimable").withArgs(depositData.nonce, depositData.amount, depositData.to);

            // Let's withdraw some eth to increase the contract's balance and make the claim possible.
            const amount = ethers.parseEther("10");
            const withdrawTx = await bridgeContract.connect(relayer).withdraw(relayer.address, { value: amount });
            await expect(withdrawTx).to.changeEtherBalances([bridgeContract, relayer.address], [amount, -amount]);
            const bridgeContractBalance = await ethers.provider.getBalance(bridgeContract.target);
            expect(bridgeContractBalance).to.be.greaterThanOrEqual((await bridgeContract.claimableGas(depositData.nonce)).amount);

            const claim_tx1 = await bridgeContract.connect(validator1).claim(depositData.nonce);

            claimable = await bridgeContract.claimableGas(depositData.nonce);
            expect(claimable.to).to.equal(ethers.ZeroAddress);
            expect(claimable.amount).to.equal(0);
            await expect(claim_tx1).to.emit(bridgeContract, "Claimed").withArgs(depositData.nonce, depositData.amount, depositData.to);
            await expect(claim_tx1).to.changeEtherBalances([bridgeContract, depositData.to], [-toEthDecimals(depositData.amount), toEthDecimals(depositData.amount)]);
        });

        it("Claim successful for payable contract", async function () {
            const { bridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const testpayableContract = await ethers.deployContract("TestPayableContract");
            await testpayableContract.waitForDeployment();

            const data1 = { nonce: 1, amount: 10000000n, to: await testpayableContract.getAddress() };
            const hashDepositData1 = await hashDepositOrWithdrawal(data1.nonce, data1.amount, data1.to);
            const new_root = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).deposit(new_root, signatures, [data1]);

            await expect(tx).to.changeEtherBalances([bridgeContract, data1.to], [0, 0, 0]);
            let depositState = (await bridgeContract.gasBridge()).depositState;
            expect(depositState.nonce).to.equal(data1.nonce);
            expect(depositState.root).to.equal(new_root);

            let claimable = await bridgeContract.claimableGas(data1.nonce);
            expect(claimable.to).to.equal(data1.to);
            expect(claimable.amount).to.equal(data1.amount);
            await expect(tx).to.emit(bridgeContract, "Claimable").withArgs(data1.nonce, data1.amount, data1.to);

            const tx2 = await bridgeContract.connect(validator1).claim(data1.nonce);

            claimable = await bridgeContract.claimableGas(data1.nonce);
            expect(claimable.to).to.equal(ethers.ZeroAddress);
            expect(claimable.amount).to.equal(0);
            await expect(tx2).to.emit(bridgeContract, "Claimed").withArgs(data1.nonce, data1.amount, data1.to);
            await expect(tx2).to.changeEtherBalances([bridgeContract, data1.to], [-toEthDecimals(data1.amount), toEthDecimals(data1.amount)]);

            await expect(bridgeContract.connect(relayer).claim(data1.nonce)).to.be.revertedWith("No claimable funds");
        });

        it("Fail to claim due to Contract not payable", async function () {
            const { bridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const data1 = { nonce: 1, amount: 100000000n, to: await bridgeContract.getAddress() };
            const hashDepositData1 = await hashDepositOrWithdrawal(data1.nonce, data1.amount, data1.to);
            const new_root = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await bridgeContract.connect(relayer).deposit(new_root, signatures, [data1]);

            await expect(tx).to.changeEtherBalances([bridgeContract, data1.to], [0, 0, 0]);
            let depositState = (await bridgeContract.gasBridge()).depositState;
            expect(depositState.nonce).to.equal(data1.nonce);
            expect(depositState.root).to.equal(new_root);

            let claimable = await bridgeContract.claimableGas(Depositdata1.nonce);
            expect(claimable.to).to.equal(data1.to);
            expect(claimable.amount).to.equal(data1.amount);
            await expect(tx).to.emit(bridgeContract, "Claimable").withArgs(data1.nonce, data1.amount, data1.to);

            await expect(bridgeContract.connect(validator1).claim(data1.nonce)).to.be.revertedWith("Transfer failed");
        });

        it("Fail to claim for not existed nonce in the claim table", async function () {
            const { bridgeContract, validator1 } = await loadFixture(deployBridgeFixture);
            await expect(bridgeContract.connect(validator1).claim(3)).to.be.revertedWith("No claimable funds");
        });
    });

    describe("Lock Function", async function () {
        it("Lock with SecurityGuard Account and Unlock with Governor", async function () {
            const { bridgeContract, validator1, governor, securityGuard } = await loadFixture(deployBridgeFixture);

            await bridgeContract.connect(securityGuard).lock();
            expect(await bridgeContract.locked()).to.equal(true);

            // unlock with the governor
            await expect(bridgeContract.connect(validator1).unlock()).to.be.revertedWith("Not governor");
            await bridgeContract.connect(governor).unlock();
            expect(await bridgeContract.locked()).to.equal(false);
        });

        it("Cannot unlock if already unlocked", async function () {
            const { bridgeContract, governor } = await loadFixture(deployBridgeFixture);
            await expect(bridgeContract.connect(governor).unlock()).to.be.revertedWith("Contract is already unlocked.");
        });

        it("Cannot deposit, claim, withdraw or lock if contract is locked", async function () {
            const { bridgeContract, relayer, securityGuard } = await loadFixture(deployBridgeFixture);
            await bridgeContract.connect(securityGuard).lock()

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);
            await expect(bridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1])).to.be.revertedWith("Contract is locked");
            await expect(bridgeContract.connect(relayer).claim(Depositdata1.nonce)).to.be.revertedWith("Contract is locked");
            const withdrawData = { nonce: 1, amount: ethers.parseEther("1"), to: relayer.address };
            await expect(bridgeContract.connect(relayer).withdraw(withdrawData.to, { value: withdrawData.amount })).to.be.revertedWith("Contract is locked");
            await expect(bridgeContract.connect(securityGuard).lock()).to.be.revertedWith("Contract is locked");
        });
    });
});

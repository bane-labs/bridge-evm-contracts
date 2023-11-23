import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { getValidatorSignatures } from "../utils/signature-utils";
import {
    // relayer, validator1, validator2, validator3, validator4, validator5, validator6, validator7,
    to1, to2, to3, to4, to5, to6, to7, to8, to9, to0,
    toEthDecimals, toNeoDecimals, hashDepositOrWithdrawal, fundContract, computeRoot, validator1, validator2, validator3
} from "./helper";

const Depositdata1 = { to: validator1, amount: 100000000n, nonce: 1 };
const Depositdata2 = { to: validator2, amount: 100000000n, nonce: 2 };
const Depositdata3 = { to: validator3, amount: 200000000n, nonce: 3 };

describe("Hash Tree Bridge contract", function () {
    async function deployBridgeFixture() {
        const [
            relayer,
            validator1,
            validator2,
            validator3,
            validator4,
            validator5,
            validator6,
            validator7
        ] = await ethers.getSigners();
        const hashTreebridgeContract = await ethers.deployContract("HashTreeBridgeContract");
        await hashTreebridgeContract.waitForDeployment();
        return {
            hashTreebridgeContract,
            relayer,
            validator1,
            validator2,
            validator3,
            validator4,
            validator5,
            validator6,
            validator7
        }
    }

    describe("Deployment", function () {
        it("Should have the right relayer", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            expect(await hashTreebridgeContract.relayer()).to.equal(relayer.address);
        });

        it("Should have the right validators", async function () {
            const { hashTreebridgeContract, validator1, validator2, validator3, validator4, validator5, validator6, validator7 } = await loadFixture(deployBridgeFixture);
            expect(await hashTreebridgeContract.validators(0)).to.equal(validator1.address);
            expect(await hashTreebridgeContract.validators(1)).to.equal(validator2.address);
            expect(await hashTreebridgeContract.validators(2)).to.equal(validator3.address);
            expect(await hashTreebridgeContract.validators(3)).to.equal(validator4.address);
            expect(await hashTreebridgeContract.validators(4)).to.equal(validator5.address);
            expect(await hashTreebridgeContract.validators(5)).to.equal(validator6.address);
            expect(await hashTreebridgeContract.validators(6)).to.equal(validator7.address);
            await expect(hashTreebridgeContract.validators(7)).to.be.revertedWithoutReason();
        });
    });

    describe("Deposit", async function () {
        it("Deposit the first Nonce", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(hashTreebridgeContract, relayer);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            const tx = await hashTreebridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1]);
            await expect(tx).to.changeEtherBalances([hashTreebridgeContract, Depositdata1.to], [-toEthDecimals(Depositdata1.amount), toEthDecimals(Depositdata1.amount)]);
        });

        it("Deposit with Multiple Continous Nonce", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(hashTreebridgeContract, relayer);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const hashDepositData2 = await hashDepositOrWithdrawal(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_root = await computeRoot(root1, hashDepositData2);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await hashTreebridgeContract.connect(relayer).deposit(new_root, signatures, [Depositdata1, Depositdata2]);

            await expect(tx).to.changeEtherBalances([hashTreebridgeContract, Depositdata1.to, Depositdata2.to], [-toEthDecimals(Depositdata1.amount + Depositdata2.amount), toEthDecimals(Depositdata1.amount), toEthDecimals(Depositdata2.amount)]);
            await expect(tx).to.emit(hashTreebridgeContract, "Deposit").withArgs(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            await expect(tx).to.emit(hashTreebridgeContract, "Deposit").withArgs(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);

            expect(await hashTreebridgeContract.depositNonce()).to.equal(Depositdata2.nonce);
            expect(await hashTreebridgeContract.depositRoot()).to.equal(new_root);
        });

        it("Deposit with Multiple Times with different Nonce Array", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(hashTreebridgeContract, relayer);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures_first = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);
            await hashTreebridgeContract.connect(relayer).deposit(root1, signatures_first, [Depositdata1]);

            //calculate the root and signatures for the second deposit
            const hashDepositData2 = await hashDepositOrWithdrawal(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);
            const hash12 = await computeRoot(root1, hashDepositData2);
            const hashDepositData3 = await hashDepositOrWithdrawal(Depositdata3.nonce, Depositdata3.amount, Depositdata3.to);
            const hash123 = await computeRoot(hash12, hashDepositData3);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [hash123]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await hashTreebridgeContract.connect(relayer).deposit(hash123, signatures, [Depositdata2, Depositdata3]);

            await expect(tx).to.changeEtherBalances([hashTreebridgeContract, Depositdata2.to, Depositdata3.to], [-toEthDecimals(Depositdata2.amount + Depositdata3.amount), toEthDecimals(Depositdata2.amount), toEthDecimals(Depositdata3.amount)]);
            await expect(tx).to.emit(hashTreebridgeContract, "Deposit").withArgs(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);
            await expect(tx).to.emit(hashTreebridgeContract, "Deposit").withArgs(Depositdata3.nonce, Depositdata3.amount, Depositdata3.to);

            expect(await hashTreebridgeContract.depositNonce()).to.equal(Depositdata3.nonce);
            expect(await hashTreebridgeContract.depositRoot()).to.equal(hash123);
        });

        it("Deposit with insufficient fund of Contract", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const hashDepositData2 = await hashDepositOrWithdrawal(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_root = await computeRoot(root1, hashDepositData2);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await hashTreebridgeContract.connect(relayer).deposit(new_root, signatures, [Depositdata1, Depositdata2]);
            // check the balance is not change for the recipient address; but the root and depositNonce are both updated
            await expect(tx).to.changeEtherBalances([hashTreebridgeContract, Depositdata1.to, Depositdata2.to], [0, 0, 0]);
            expect(await hashTreebridgeContract.depositNonce()).to.equal(Depositdata2.nonce);
            expect(await hashTreebridgeContract.depositRoot()).to.equal(new_root);
            expect(await hashTreebridgeContract.claimableTo(Depositdata1.nonce)).to.equal(Depositdata1.to);
            expect(await hashTreebridgeContract.claimableAmount(Depositdata1.nonce)).to.equal(Depositdata1.amount);
            expect(await hashTreebridgeContract.claimableTo(Depositdata2.nonce)).to.equal(Depositdata2.to);
            expect(await hashTreebridgeContract.claimableAmount(Depositdata2.nonce)).to.equal(Depositdata2.amount);
            await expect(tx).to.emit(hashTreebridgeContract, "Claimable").withArgs(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            await expect(tx).to.emit(hashTreebridgeContract, "Claimable").withArgs(Depositdata2.nonce, Depositdata2.amount, Depositdata2.to);

        });

        it("Deposit When Recipient is Contract", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(hashTreebridgeContract, relayer);

            const data2 = { nonce: 2, amount: 200000000n, to: await hashTreebridgeContract.getAddress() };

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const hashDepositData2 = await hashDepositOrWithdrawal(data2.nonce, data2.amount, data2.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_root = await computeRoot(root1, hashDepositData2);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await hashTreebridgeContract.connect(relayer).deposit(new_root, signatures, [Depositdata1, data2]);

            await expect(tx).to.changeEtherBalances([hashTreebridgeContract, Depositdata1.to], [-toEthDecimals(Depositdata1.amount), toEthDecimals(Depositdata1.amount)]);
            expect(await hashTreebridgeContract.depositNonce()).to.equal(data2.nonce);
            expect(await hashTreebridgeContract.depositRoot()).to.equal(new_root);
            //check claim table change
            expect(await hashTreebridgeContract.claimableTo(Depositdata1.nonce)).to.equal(ethers.ZeroAddress);
            expect(await hashTreebridgeContract.claimableAmount(Depositdata1.nonce)).to.equal(0);
            expect(await hashTreebridgeContract.claimableTo(data2.nonce)).to.equal(data2.to);
            expect(await hashTreebridgeContract.claimableAmount(data2.nonce)).to.equal(data2.amount);

        });

        it("Deposit When Deposit Length is Equal to 10", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(hashTreebridgeContract, relayer);

            const dataArray = [];
            let hashResult = ethers.ZeroHash;
            for (let i = 0; i < 10; i++) {
                dataArray.push({ nonce: i + 1, amount: 100000000n, to: relayer.address });
                hashResult = await computeRoot(hashResult, await hashDepositOrWithdrawal(dataArray[i].nonce, dataArray[i].amount, dataArray[i].to));
            }
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [hashResult]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await hashTreebridgeContract.connect(relayer).deposit(hashResult, signatures, dataArray);
            await expect(tx).to.changeEtherBalances([hashTreebridgeContract, relayer.address], [-toEthDecimals(dataArray[0].amount * 10n), toEthDecimals(dataArray[0].amount * 10n)]);
            expect(await hashTreebridgeContract.depositNonce()).to.equal(10);
            expect(await hashTreebridgeContract.depositRoot()).to.equal(hashResult);
            for (let i = 0; i < 10; i++) {
                await expect(tx).to.emit(hashTreebridgeContract, "Deposit").withArgs(dataArray[i].nonce, dataArray[i].amount, dataArray[i].to);
            }
        });

        //TODO: This needs to be discussed whether revert or not
        it("Deposit When Recipient Address is Zero Address", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(hashTreebridgeContract, relayer);

            const data_withZeroAddress = { nonce: 1, amount: 100000000n, to: ethers.ZeroAddress };
            const root = await computeRoot(ethers.ZeroHash, await hashDepositOrWithdrawal(data_withZeroAddress.nonce, data_withZeroAddress.amount, data_withZeroAddress.to));

            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await hashTreebridgeContract.connect(relayer).deposit(root, signatures, [data_withZeroAddress]);
            await expect(tx).to.changeEtherBalances([hashTreebridgeContract, ethers.ZeroAddress], [-toEthDecimals(data_withZeroAddress.amount), toEthDecimals(data_withZeroAddress.amount)]);
            expect(await hashTreebridgeContract.depositNonce()).to.equal(1);
            expect(await hashTreebridgeContract.depositRoot()).to.equal(root);
            await expect(tx).to.emit(hashTreebridgeContract, "Deposit").withArgs(data_withZeroAddress.nonce, data_withZeroAddress.amount,data_withZeroAddress.to);
        
        });

        it("Should revert with empty proofs", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await expect(hashTreebridgeContract.connect(relayer).deposit(ethers.ZeroHash, [], [])).to.be.revertedWith("At least 1 deposit is required.");
        });

        it("Should revert with proofs length greater than 10", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            const dataArray = [];
            let hashResult = ethers.ZeroHash;
            for (let i = 0; i < 11; i++) {
                dataArray.push({ nonce: i + 1, amount: 100000000n, to: relayer.address });
                hashResult = await computeRoot(hashResult, await hashDepositOrWithdrawal(dataArray[i].nonce, dataArray[i].amount, dataArray[i].to));
            }
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [hashResult]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            await expect(hashTreebridgeContract.connect(relayer).deposit(hashResult, signatures, dataArray)).to.be.revertedWith("Too many deposits provided.");

        });

        it("Should revert with the wrong first nonce", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await expect(hashTreebridgeContract.connect(relayer).deposit(ethers.ZeroHash, [], [Depositdata2])).to.be.revertedWith("Only the next nonce is allowed in the first proof.");
        });

        it("Should revert when nonce is not subsequent", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await expect(hashTreebridgeContract.connect(relayer).deposit(ethers.ZeroHash, [], [Depositdata1, Depositdata3])).to.be.revertedWith("The nonces of the proofs must be subsequent.");
        });

        it("Should revert when signature length less than 5", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(hashTreebridgeContract, relayer);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [0, 2, 3, 4]);

            await expect(hashTreebridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1])).to.be.revertedWith("Invalid number of signatures.");
        });

        it("Should revert when signature length is 5 but with two duplicate signature", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(hashTreebridgeContract, relayer);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 1, 3, 4, 5]);

            await expect(hashTreebridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1])).to.be.revertedWith("Invalid or insufficient validator signatures.");
        });

        it("Should revert when signature verify failed", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(hashTreebridgeContract, relayer);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            //index 0 refers to relayer signer in the method getValidatorSignatures, thus there are only 4 validator signatures and the signature verification should fail.
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [0, 2, 3, 4, 5]);

            await expect(hashTreebridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1])).to.be.revertedWith("Invalid or insufficient validator signatures.");
        });

        it("Should revert when root is invalid", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);
            await fundContract(hashTreebridgeContract, relayer);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const root1 = await computeRoot(hashDepositData1, hashDepositData1);
            const encodeRoot1 = ethers.solidityPackedKeccak256(["bytes32"], [root1]);
            const signatures = await getValidatorSignatures(ethers.getBytes(encodeRoot1), [1, 2, 3, 4, 5]);

            await expect(hashTreebridgeContract.connect(relayer).deposit(root1, signatures, [Depositdata1])).to.be.revertedWith("Invalid deposit root.");
        });

    });

    describe("Withdraw", function () {
        it("withdraw only once", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const withdrawData = { nonce: 1, amount: ethers.parseEther("1"), to: relayer.address };
            const tx = await hashTreebridgeContract.connect(relayer).withdraw(withdrawData.to, { value: withdrawData.amount });

            const hashWithdrawData1 = await hashDepositOrWithdrawal(withdrawData.nonce, toNeoDecimals(withdrawData.amount), relayer.address);
            const new_withdrawRoot = await computeRoot(ethers.ZeroHash, hashWithdrawData1);

            expect(await hashTreebridgeContract.withdrawalNonce()).to.be.equal(1);
            expect(await hashTreebridgeContract.withdrawalRoot()).to.be.equal(new_withdrawRoot);
            await expect(tx).to.emit(hashTreebridgeContract, "Withdrawal").withArgs(1, toNeoDecimals(withdrawData.amount), relayer.address, relayer.address);

        });

        it("withdraw multiple times", async function () {
            const { hashTreebridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const withdrawData1 = { nonce: 1, amount: ethers.parseEther("1"), to: relayer.address };
            const tx = await hashTreebridgeContract.connect(relayer).withdraw(withdrawData1.to, { value: withdrawData1.amount });
            const withdrawData2 = { nonce: 2, amount: ethers.parseEther("2"), to: validator1.address };

            const hashWithdrawData1 = await hashDepositOrWithdrawal(withdrawData1.nonce, toNeoDecimals(withdrawData1.amount), relayer.address);
            const hash1 = await computeRoot(ethers.ZeroHash, hashWithdrawData1);
            const hashWithdrawData2 = await hashDepositOrWithdrawal(withdrawData2.nonce, toNeoDecimals(withdrawData2.amount), validator1.address);
            const hash12 = await computeRoot(hash1, hashWithdrawData2);

            const tx2 = await hashTreebridgeContract.connect(relayer).withdraw(withdrawData2.to, { value: withdrawData2.amount });

            expect(await hashTreebridgeContract.withdrawalNonce()).to.be.equal(2);
            expect(await hashTreebridgeContract.withdrawalRoot()).to.be.equal(hash12);
            await expect(tx2).to.emit(hashTreebridgeContract, "Withdrawal").withArgs(2, toNeoDecimals(withdrawData2.amount), validator1.address, relayer.address);

        });

        it("withdraw with amount edge case", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            const withdrawData = { nonce: 1, amount: ethers.parseEther("1.00000001"), to: relayer.address };
            const tx = await hashTreebridgeContract.connect(relayer).withdraw(withdrawData.to, { value: withdrawData.amount });

            const hashWithdrawData1 = await hashDepositOrWithdrawal(withdrawData.nonce, toNeoDecimals(withdrawData.amount), relayer.address);
            const new_withdrawRoot = await computeRoot(ethers.ZeroHash, hashWithdrawData1);

            expect(await hashTreebridgeContract.withdrawalNonce()).to.be.equal(1);
            expect(await hashTreebridgeContract.withdrawalRoot()).to.be.equal(new_withdrawRoot);
            await expect(tx).to.emit(hashTreebridgeContract, "Withdrawal").withArgs(1, toNeoDecimals(withdrawData.amount), relayer.address, relayer.address);
            await expect(tx).to.changeEtherBalances([hashTreebridgeContract, relayer], [ethers.parseEther("1.00000001"), -ethers.parseEther("1.00000001")]);
        });

        it("withdraw with the wrong amount", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            await expect(hashTreebridgeContract.connect(relayer).withdraw(relayer, { value: ethers.parseEther("0.000000001") })).to.be.revertedWith("Only amounts with 8 non-zero decimals allowed for withdrawal");
        });

        it("withdraw with the amount smaller than minWithdrawalAmount", async function () {
            const { hashTreebridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            await expect(hashTreebridgeContract.connect(relayer).withdraw(relayer, { value: ethers.parseEther("0.9") })).to.be.revertedWith("Smaller than minimum withdrawal amount");
        });
    });

    describe("Claim", function () {
        it("Claim successful for EOA account", async function () {
            const { hashTreebridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const hashDepositData1 = await hashDepositOrWithdrawal(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            const new_root = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await hashTreebridgeContract.connect(relayer).deposit(new_root, signatures, [Depositdata1]);

            await expect(tx).to.changeEtherBalances([hashTreebridgeContract, Depositdata1.to], [0, 0, 0]);
            expect(await hashTreebridgeContract.depositNonce()).to.equal(Depositdata1.nonce);
            expect(await hashTreebridgeContract.depositRoot()).to.equal(new_root);

            expect(await hashTreebridgeContract.claimableTo(Depositdata1.nonce)).to.equal(Depositdata1.to);
            expect(await hashTreebridgeContract.claimableAmount(Depositdata1.nonce)).to.equal(Depositdata1.amount);
            await expect(tx).to.emit(hashTreebridgeContract, "Claimable").withArgs(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);

            await fundContract(hashTreebridgeContract, relayer);
            const claim_tx1 = await hashTreebridgeContract.connect(validator1).claim(Depositdata1.nonce);

            expect(await hashTreebridgeContract.claimableTo(Depositdata1.nonce)).to.equal(ethers.ZeroAddress);
            expect(await hashTreebridgeContract.claimableAmount(Depositdata1.nonce)).to.equal(0);
            await expect(claim_tx1).to.emit(hashTreebridgeContract, "Claimed").withArgs(Depositdata1.nonce, Depositdata1.amount, Depositdata1.to);
            await expect(claim_tx1).to.changeEtherBalances([hashTreebridgeContract, Depositdata1.to], [-toEthDecimals(Depositdata1.amount), toEthDecimals(Depositdata1.amount)]);

        });

        it("Claim successful for payable contract", async function () {
            const { hashTreebridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);
            await fundContract(hashTreebridgeContract, relayer);
            const testpayableContract = await ethers.deployContract("TestPayableContract");
            await testpayableContract.waitForDeployment();

            const data1 = { nonce: 1, amount: 10000000n, to: await testpayableContract.getAddress() };
            const hashDepositData1 = await hashDepositOrWithdrawal(data1.nonce, data1.amount, data1.to);
            const new_root = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await hashTreebridgeContract.connect(relayer).deposit(new_root, signatures, [data1]);

            await expect(tx).to.changeEtherBalances([hashTreebridgeContract, data1.to], [0, 0, 0]);
            expect(await hashTreebridgeContract.depositNonce()).to.equal(data1.nonce);
            expect(await hashTreebridgeContract.depositRoot()).to.equal(new_root);

            expect(await hashTreebridgeContract.claimableTo(data1.nonce)).to.equal(data1.to);
            expect(await hashTreebridgeContract.claimableAmount(data1.nonce)).to.equal(data1.amount);
            await expect(tx).to.emit(hashTreebridgeContract, "Claimable").withArgs(data1.nonce, data1.amount, data1.to);

            const tx2 = await hashTreebridgeContract.connect(validator1).claim(data1.nonce);

            expect(await hashTreebridgeContract.claimableTo(data1.nonce)).to.equal(ethers.ZeroAddress);
            expect(await hashTreebridgeContract.claimableAmount(data1.nonce)).to.equal(0);
            await expect(tx2).to.emit(hashTreebridgeContract, "Claimed").withArgs(data1.nonce, data1.amount, data1.to);
            await expect(tx2).to.changeEtherBalances([hashTreebridgeContract, data1.to], [-toEthDecimals(data1.amount), toEthDecimals(data1.amount)]);

            await expect(hashTreebridgeContract.connect(relayer).claim(data1.nonce)).to.be.revertedWith("No claimable funds");
        });

        it("Fail to claim due to Contract not payable", async function () {
            const { hashTreebridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const data1 = { nonce: 1, amount: 100000000n, to: await hashTreebridgeContract.getAddress() };
            const hashDepositData1 = await hashDepositOrWithdrawal(data1.nonce, data1.amount, data1.to);
            const new_root = await computeRoot(ethers.ZeroHash, hashDepositData1);
            const new_encodeRoot = ethers.solidityPackedKeccak256(["bytes32"], [new_root]);
            const signatures = await getValidatorSignatures(ethers.getBytes(new_encodeRoot), [1, 2, 3, 4, 5]);

            const tx = await hashTreebridgeContract.connect(relayer).deposit(new_root, signatures, [data1]);

            await expect(tx).to.changeEtherBalances([hashTreebridgeContract, data1.to], [0, 0, 0]);
            expect(await hashTreebridgeContract.depositNonce()).to.equal(data1.nonce);
            expect(await hashTreebridgeContract.depositRoot()).to.equal(new_root);

            expect(await hashTreebridgeContract.claimableTo(data1.nonce)).to.equal(data1.to);
            expect(await hashTreebridgeContract.claimableAmount(data1.nonce)).to.equal(data1.amount);
            await expect(tx).to.emit(hashTreebridgeContract, "Claimable").withArgs(data1.nonce, data1.amount, data1.to);

            await fundContract(hashTreebridgeContract, relayer);
            await expect(hashTreebridgeContract.connect(validator1).claim(data1.nonce)).to.be.revertedWith("Transfer failed");
        });

        it("Fail to claim for not existed nonce in the claim table", async function () {
            const { hashTreebridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);
            await expect(hashTreebridgeContract.connect(validator1).claim(3)).to.be.revertedWith("No claimable funds");
        });

    });
});

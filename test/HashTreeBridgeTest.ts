import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { getValidatorSignatures } from "../utils/signature-utils";
import {
    // relayer, validator1, validator2, validator3, validator4, validator5, validator6, validator7,
    to1, to2, to3, to4, to5, to6, to7, to8, to9, to0,
    toEthDecimals, hashDepositOrWithdrawal, fundContract, computeRoot, validator1, validator2, validator3
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

    });
});

import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { getValidatorSignatures } from "../utils/signature-utils";
import { ZeroAddress } from "ethers";

describe("Bridge Management contract", function () {
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
            securityGuard
        ] = await ethers.getSigners();
        const bridgeManagementContract = await ethers.deployContract("BridgeManagementContract");
        await bridgeManagementContract.waitForDeployment();
        return {
            bridgeManagementContract: bridgeManagementContract,
            relayer,
            validator1,
            validator2,
            validator3,
            validator4,
            validator5,
            validator6,
            validator7,
            governor,
            securityGuard
        }
    }

    describe("Deployment", function () {
        it("Should have the right relayer", async function () {
            const { bridgeManagementContract: bridgeManagementContract, relayer } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementContract.relayer()).to.equal(relayer.address);
        });

        it("Should have the right validators", async function () {
            const { bridgeManagementContract: bridgeManagementContract, validator1, validator2, validator3, validator4, validator5, validator6, validator7 } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementContract.validators(0)).to.equal(validator1.address);
            expect(await bridgeManagementContract.validators(1)).to.equal(validator2.address);
            expect(await bridgeManagementContract.validators(2)).to.equal(validator3.address);
            expect(await bridgeManagementContract.validators(3)).to.equal(validator4.address);
            expect(await bridgeManagementContract.validators(4)).to.equal(validator5.address);
            expect(await bridgeManagementContract.validators(5)).to.equal(validator6.address);
            expect(await bridgeManagementContract.validators(6)).to.equal(validator7.address);
            await expect(bridgeManagementContract.validators(7)).to.be.revertedWithoutReason();
        });

        it("Should have the right owner", async function () {
            const { bridgeManagementContract: bridgeManagementContract, validator1 } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementContract.owner()).to.equal(validator1.address);
        });

        it("Should have the right governor", async function () {
            const { bridgeManagementContract: bridgeManagementContract, governor } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementContract.governor()).to.equal(governor.address);
        });

        it("Should have the right securityGuard", async function () {
            const { bridgeManagementContract: bridgeManagementContract, securityGuard } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementContract.securityGuard()).to.equal(securityGuard.address);
        });

    });

    describe("Bridge parameter setting", function () {
        it("Set withdrawal fee", async function () {
            const { bridgeManagementContract, governor } = await loadFixture(deployBridgeFixture);
            const oldFee = ethers.parseEther("0.1");
            await expect(await bridgeManagementContract.withdrawalFee()).to.be.equal(oldFee);
            const newFee = ethers.parseEther("0.2");
            const tx = await bridgeManagementContract.connect(governor).setWithdrawalFee(newFee);
            await expect(tx).to.emit(bridgeManagementContract, "WithdrawalFeeChanged").withArgs(newFee);
            await expect(await bridgeManagementContract.withdrawalFee()).to.be.equal(newFee);
        });

        it("Set min withdrawal amount", async function () {
            const { bridgeManagementContract, governor } = await loadFixture(deployBridgeFixture);
            const oldMinAmount = ethers.parseEther("1");
            await expect(await bridgeManagementContract.minWithdrawalAmount()).to.be.equal(oldMinAmount);
            const newMinAmount = ethers.parseEther("0.2");
            const tx = await bridgeManagementContract.connect(governor).setMinWithdrawalAmount(newMinAmount);
            await expect(tx).to.emit(bridgeManagementContract, "MinWithdrawalAmountChanged").withArgs(newMinAmount);
            await expect(await bridgeManagementContract.minWithdrawalAmount()).to.be.equal(newMinAmount);
        });

        it("Set max withdrawal amount", async function () {
            const { bridgeManagementContract, governor } = await loadFixture(deployBridgeFixture);
            const oldMaxAmount = ethers.parseEther("10000");
            await expect(await bridgeManagementContract.maxWithdrawalAmount()).to.be.equal(oldMaxAmount);
            const newMaxAmount = ethers.parseEther("5000");
            const tx = await bridgeManagementContract.connect(governor).setMaxWithdrawalAmount(newMaxAmount);
            await expect(tx).to.emit(bridgeManagementContract, "MaxWithdrawalAmountChanged").withArgs(newMaxAmount);
            await expect(await bridgeManagementContract.maxWithdrawalAmount()).to.be.equal(newMaxAmount);
        });

        it("Set invalid min and max withdrawal amounts", async function () {
            const { bridgeManagementContract, governor } = await loadFixture(deployBridgeFixture);
            const minWithdrawalAmount = await bridgeManagementContract.minWithdrawalAmount();
            const maxWithdrawalAmount = await bridgeManagementContract.maxWithdrawalAmount();

            let tx = bridgeManagementContract.connect(governor).setMinWithdrawalAmount(maxWithdrawalAmount);
            await expect(tx).to.be.revertedWith("Amount must be less than the maximal withdrawal amount");

            tx = bridgeManagementContract.connect(governor).setMaxWithdrawalAmount(minWithdrawalAmount);
            await expect(tx).to.be.revertedWith("Amount must be greater than the minimal withdrawal amount");
        });

        it("Set max deposits per distribution", async function () {
            const { bridgeManagementContract: bridgeManagementContract, governor } = await loadFixture(deployBridgeFixture);
            const maxDepositsPerDistribution = await bridgeManagementContract.maxDepositsPerDistribution();
            const newMaxDepositsPerDistribution = 10;
            const tx = bridgeManagementContract.connect(governor).setMaxDepositsPerDistribution(newMaxDepositsPerDistribution);
            await expect(tx).to.emit(bridgeManagementContract, "MaxDepositsPerDistributionChanged").withArgs(newMaxDepositsPerDistribution);
            await expect(await bridgeManagementContract.maxDepositsPerDistribution()).to.be.equal(newMaxDepositsPerDistribution);
        });

        it("Fail setting max deposits per distribution to zero", async function () {
            const { bridgeManagementContract: bridgeManagementContract, governor } = await loadFixture(deployBridgeFixture);
            const maxDepositsPerDistribution = await bridgeManagementContract.maxDepositsPerDistribution();
            await expect(maxDepositsPerDistribution).to.be.greaterThan(0);

            let tx = bridgeManagementContract.connect(governor).setMaxDepositsPerDistribution(0);
            await expect(tx).to.be.revertedWith("Value must be greater than 0");
        });
    });

    describe("Bridge role setting", function () {
        it("Set owner", async function () {
            const { bridgeManagementContract, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            const tx = await bridgeManagementContract.connect(validator1).setOwner(validator2.address);
            await expect(tx).to.emit(bridgeManagementContract, "SetOwner").withArgs(validator2.address);
            await expect(await bridgeManagementContract.owner()).to.be.equal(validator2.address);
        });

        it("Set validators with unique address", async function () {
            const { bridgeManagementContract, validator1 } = await loadFixture(deployBridgeFixture);
            const new_validators = [ethers.Wallet.createRandom().address, ethers.Wallet.createRandom().address];
            const tx = await bridgeManagementContract.connect(validator1).setValidators(new_validators, 2);
            await expect(tx).to.emit(bridgeManagementContract, "SetValidators").withArgs(new_validators, 2);
            await expect(await bridgeManagementContract.validators(0)).to.be.equal(new_validators[0]);
            await expect(await bridgeManagementContract.validators(1)).to.be.equal(new_validators[1]);
            await expect(await bridgeManagementContract.requiredValidatorSignaturesForDeposit()).to.be.equal(2);
        });

        it("Set validators with duplicate addresses", async function () {
            const { bridgeManagementContract, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            const new_validators = [validator1.address, validator1.address, validator2.address];
            const tx = bridgeManagementContract.connect(validator1).setValidators(new_validators, 2);
            await expect(tx).to.be.revertedWith("Duplicate validator addresses are not allowed");
        });

        it("Set validators with threshold greater than validators length", async function () {
            const { bridgeManagementContract, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            const new_validators = [validator1.address, validator2.address];
            const tx = bridgeManagementContract.connect(validator1).setValidators(new_validators, 3);
            await expect(tx).to.be.revertedWith("Threshold must be greater than 0 and less than or equal to the number of validators");
        });

        it("Set validators with empty validators", async function () {
            const { bridgeManagementContract, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            const tx = bridgeManagementContract.connect(validator1).setValidators([], 1);
            await expect(tx).to.be.revertedWith("Validators array must contain at least one address");
        });

        it("Set validators with zero address validators", async function () {
            const { bridgeManagementContract, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            const tx = bridgeManagementContract.connect(validator1).setValidators([validator1.address, ZeroAddress], 1);
            await expect(tx).to.be.revertedWith("Validator address cannot be 0x0");
        });

        it("Set relayer", async function () {
            const { bridgeManagementContract, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            const tx = await bridgeManagementContract.connect(validator1).setRelayer(validator2.address);
            await expect(tx).to.emit(bridgeManagementContract, "SetRelayer").withArgs(validator2.address);
            await expect(await bridgeManagementContract.relayer()).to.be.equal(validator2.address);
        });

        it("Set governor", async function () {
            const { bridgeManagementContract, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            const tx = await bridgeManagementContract.connect(validator1).setGovernor(validator2.address);
            await expect(tx).to.emit(bridgeManagementContract, "SetGovernor").withArgs(validator2.address);
            await expect(await bridgeManagementContract.governor()).to.be.equal(validator2.address);
        });

        it("Set securityGuard", async function () {
            const { bridgeManagementContract, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementContract.connect(validator1).setSecurityGuard(validator2.address);
            await expect(tx).to.emit(bridgeManagementContract, "SetSecurityGuard").withArgs(validator2.address);
            await expect(await bridgeManagementContract.securityGuard()).to.be.equal(validator2.address);
        });

        it("Non-owner fail to set owner", async function () {
            const { bridgeManagementContract, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementContract.connect(validator2).setOwner(validator2.address);
            await expect(tx).to.be.revertedWith("Not owner");
        });

        it("Non-owner fail to set relayer", async function () {
            const { bridgeManagementContract, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementContract.connect(validator2).setRelayer(validator2.address);
            await expect(tx).to.be.revertedWith("Not owner");
        });

        it("Non-owner fail to set governor", async function () {
            const { bridgeManagementContract, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementContract.connect(validator2).setGovernor(validator2.address);
            await expect(tx).to.be.revertedWith("Not owner");
        });
    });

});

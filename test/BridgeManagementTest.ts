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
            securityGuard,
            owner
        ] = await ethers.getSigners();
        console.log("owner", owner.address);
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
            securityGuard,
            owner
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
            const { bridgeManagementContract: bridgeManagementContract, owner } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementContract.owner()).to.equal(owner.address);
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

    describe("Bridge role setting", function () {
        it("Set owner", async function () {
            const { bridgeManagementContract, owner, validator2 } = await loadFixture(deployBridgeFixture);
            const tx = await bridgeManagementContract.connect(owner).setOwner(validator2.address);
            await expect(tx).to.emit(bridgeManagementContract, "SetOwner").withArgs(validator2.address);
            await expect(await bridgeManagementContract.owner()).to.be.equal(validator2.address);
        });

        it("Set validators with unique address", async function () {
            const { bridgeManagementContract, owner } = await loadFixture(deployBridgeFixture);
            const new_validators = [ethers.Wallet.createRandom().address, ethers.Wallet.createRandom().address];
            const tx = await bridgeManagementContract.connect(owner).setValidators(new_validators, 2);
            await expect(tx).to.emit(bridgeManagementContract, "SetValidators").withArgs(new_validators, 2);
            await expect(await bridgeManagementContract.validators(0)).to.be.equal(new_validators[0]);
            await expect(await bridgeManagementContract.validators(1)).to.be.equal(new_validators[1]);
            await expect(await bridgeManagementContract.validatorThreshold()).to.be.equal(2);
        });

        it("Set validators multiple times", async function () {
            const { bridgeManagementContract, owner, validator1, validator2, validator3, validator4 } = await loadFixture(deployBridgeFixture);
            let new_validators = [validator1.address, validator2.address, validator3.address];
            let tx = await bridgeManagementContract.connect(owner).setValidators(new_validators, 2);
            await expect(tx).to.emit(bridgeManagementContract, "SetValidators").withArgs(new_validators, 2);
            await expect(await bridgeManagementContract.validators(0)).to.be.equal(validator1.address);
            await expect(await bridgeManagementContract.validators(1)).to.be.equal(validator2.address);
            await expect(await bridgeManagementContract.validators(2)).to.be.equal(validator3.address);
            await expect(await bridgeManagementContract.validatorThreshold()).to.be.equal(2);

            // The 3rd validator address needs to be updated
            new_validators = [validator1.address, validator2.address, validator4.address];
            tx = await bridgeManagementContract.connect(owner).setValidators(new_validators, 2);
            await expect(tx).to.emit(bridgeManagementContract, "SetValidators").withArgs(new_validators, 2);
            await expect(await bridgeManagementContract.validators(0)).to.be.equal(validator1.address);
            await expect(await bridgeManagementContract.validators(1)).to.be.equal(validator2.address);
            await expect(await bridgeManagementContract.validators(2)).to.be.equal(validator4.address);
            await expect(await bridgeManagementContract.validatorThreshold()).to.be.equal(2);
        });

        it("Set validators with duplicate addresses", async function () {
            const { bridgeManagementContract, validator1, validator2, owner } = await loadFixture(deployBridgeFixture);
            const new_validators = [validator1.address, validator1.address, validator2.address];
            const tx = bridgeManagementContract.connect(owner).setValidators(new_validators, 2);
            await expect(tx).to.be.revertedWith("Duplicate validator addresses are not allowed");
        });

        it("Set validators with threshold greater than validators length", async function () {
            const { bridgeManagementContract, validator1, validator2, owner } = await loadFixture(deployBridgeFixture);
            const new_validators = [validator1.address, validator2.address];
            const tx = bridgeManagementContract.connect(owner).setValidators(new_validators, 3);
            await expect(tx).to.be.revertedWith("Threshold must be greater than 0 and less than or equal to the number of validators");
        });

        it("Set validators with empty validators", async function () {
            const { bridgeManagementContract, owner } = await loadFixture(deployBridgeFixture);
            const tx = bridgeManagementContract.connect(owner).setValidators([], 1);
            await expect(tx).to.be.revertedWith("Validators array must contain at least one address");
        });

        it("Set validators with zero address validators", async function () {
            const { bridgeManagementContract, validator1, owner } = await loadFixture(deployBridgeFixture);
            const tx = bridgeManagementContract.connect(owner).setValidators([validator1.address, ZeroAddress], 1);
            await expect(tx).to.be.revertedWith("Validator address cannot be 0x0");
        });

        it("Set relayer", async function () {
            const { bridgeManagementContract, owner, validator2 } = await loadFixture(deployBridgeFixture);
            const tx = await bridgeManagementContract.connect(owner).setRelayer(validator2.address);
            await expect(tx).to.emit(bridgeManagementContract, "SetRelayer").withArgs(validator2.address);
            await expect(await bridgeManagementContract.relayer()).to.be.equal(validator2.address);
        });

        it("Set governor", async function () {
            const { bridgeManagementContract, owner, validator2 } = await loadFixture(deployBridgeFixture);
            const tx = await bridgeManagementContract.connect(owner).setGovernor(validator2.address);
            await expect(tx).to.emit(bridgeManagementContract, "SetGovernor").withArgs(validator2.address);
            await expect(await bridgeManagementContract.governor()).to.be.equal(validator2.address);
        });

        it("Set securityGuard", async function () {
            const { bridgeManagementContract, owner, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementContract.connect(owner).setSecurityGuard(validator2.address);
            await expect(tx).to.emit(bridgeManagementContract, "SetSecurityGuard").withArgs(validator2.address);
            await expect(await bridgeManagementContract.securityGuard()).to.be.equal(validator2.address);
        });

        it("Non-owner fail to set owner", async function () {
            const { bridgeManagementContract, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementContract.connect(validator2).setOwner(validator2.address);
            await expect(tx).to.be.revertedWith("Not owner");
        });

        it("Non-owner fail to set relayer", async function () {
            const { bridgeManagementContract, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementContract.connect(validator2).setRelayer(validator2.address);
            await expect(tx).to.be.revertedWith("Not owner");
        });

        it("Non-owner fail to set governor", async function () {
            const { bridgeManagementContract, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementContract.connect(validator2).setGovernor(validator2.address);
            await expect(tx).to.be.revertedWith("Not owner");
        });
    });

});

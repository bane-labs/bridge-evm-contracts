import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ZeroAddress } from "ethers";
import { bridge } from "../typechain-types/contracts";
import { TestBridgeManagement } from "../typechain-types";

describe("Bridge Management", function () {
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
            owner,
            deployer,
            funder
        ] = await ethers.getSigners();
        const BridgeManagementFactory = (await ethers.getContractFactory("TestBridgeManagement"));
        const proxy = await upgrades.deployProxy(BridgeManagementFactory, [
            owner.address,
            relayer.address,
            5,
            [validator1.address, validator2.address, validator3.address, validator4.address, validator5.address, validator6.address, validator7.address],
            governor.address,
            securityGuard.address,
            funder.address
        ], { kind: "uups", unsafeAllow: ["constructor"] });
        await proxy.waitForDeployment();
        const bridgeManagementImpl = await ethers.getContractAt("TestBridgeManagement", await proxy.getAddress());

        // Upgrade the bridge management contract to V2
        await bridgeManagementImpl.connect(owner).upgradeToV2();

        return {
            bridgeManagementImpl,
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
            owner,
            funder
        }
    }

    describe("Deployment", function () {
        it("Should have the right relayer", async function () {
            const { bridgeManagementImpl, relayer } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.getRelayer()).to.equal(relayer.address);
        });

        it("Should have the right validators", async function () {
            const { bridgeManagementImpl, validator1, validator2, validator3, validator4, validator5, validator6, validator7 } = await loadFixture(deployBridgeFixture);
            expect((await bridgeManagementImpl.getValidators())).to.have.length(7);
            expect((await bridgeManagementImpl.getValidators())[0]).to.equal(validator1.address);
            expect((await bridgeManagementImpl.getValidators())[1]).to.equal(validator2.address);
            expect((await bridgeManagementImpl.getValidators())[2]).to.equal(validator3.address);
            expect((await bridgeManagementImpl.getValidators())[3]).to.equal(validator4.address);
            expect((await bridgeManagementImpl.getValidators())[4]).to.equal(validator5.address);
            expect((await bridgeManagementImpl.getValidators())[5]).to.equal(validator6.address);
            expect((await bridgeManagementImpl.getValidators())[6]).to.equal(validator7.address);
        });

        it("Should have the right owner", async function () {
            const { bridgeManagementImpl, owner } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.owner()).to.equal(owner.address);
        });

        it("Should have the right governor", async function () {
            const { bridgeManagementImpl, governor } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.getGovernor()).to.equal(governor.address);
        });

        it("Should have the right securityGuard", async function () {
            const { bridgeManagementImpl, securityGuard } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.getSecurityGuard()).to.equal(securityGuard.address);
        });

        it("Should have the right funder", async function () {
            const { bridgeManagementImpl, funder } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.getFunder()).to.equal(funder.address);
        });
    });

    describe("Bridge role setting", function () {
        it("Set owner", async function () {
            const { bridgeManagementImpl, owner, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            // Start ownership transfer
            const txTransfer = await bridgeManagementImpl.connect(owner).transferOwnership(validator2.address);
            await expect(txTransfer).to.emit(bridgeManagementImpl, "OwnershipTransferStarted").withArgs(owner.address, validator2.address);
            await expect(await bridgeManagementImpl.pendingOwner()).to.be.equal(validator2.address);
            await expect(await bridgeManagementImpl.owner()).to.be.equal(owner.address);

            // Try accepting with wrong account
            const txAcceptWrongAccount = bridgeManagementImpl.connect(validator1).acceptOwnership();
            await expect(txAcceptWrongAccount).to.be.revertedWithCustomError(bridgeManagementImpl, "OwnableUnauthorizedAccount");

            // Accept ownership with correct account
            const txAccept = await bridgeManagementImpl.connect(validator2).acceptOwnership();
            await expect(txAccept).to.emit(bridgeManagementImpl, "OwnershipTransferred").withArgs(owner.address, validator2.address);
            await expect(await bridgeManagementImpl.pendingOwner()).to.be.equal(ZeroAddress);
            await expect(await bridgeManagementImpl.owner()).to.be.equal(validator2.address);
        });

        it("Set relayer", async function () {
            const { bridgeManagementImpl, owner, validator2 } = await loadFixture(deployBridgeFixture);
            const tx = await bridgeManagementImpl.connect(owner).setRelayer(validator2.address);
            await expect(tx).to.emit(bridgeManagementImpl, "RelayerChange").withArgs(validator2.address);
            await expect(await bridgeManagementImpl.getRelayer()).to.be.equal(validator2.address);
        });

        it("Set governor", async function () {
            const { bridgeManagementImpl, owner, validator2 } = await loadFixture(deployBridgeFixture);
            const tx = await bridgeManagementImpl.connect(owner).setGovernor(validator2.address);
            await expect(tx).to.emit(bridgeManagementImpl, "GovernorChange").withArgs(validator2.address);
            await expect(await bridgeManagementImpl.getGovernor()).to.be.equal(validator2.address);
        });

        it("Set securityGuard", async function () {
            const { bridgeManagementImpl, owner, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementImpl.connect(owner).setSecurityGuard(validator2.address);
            await expect(tx).to.emit(bridgeManagementImpl, "SecurityGuardChange").withArgs(validator2.address);
            await expect(await bridgeManagementImpl.getSecurityGuard()).to.be.equal(validator2.address);
        });

        it("Set funder", async function () {
            const { bridgeManagementImpl, owner, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementImpl.connect(owner).setFunder(validator2.address);
            await expect(tx).to.emit(bridgeManagementImpl, "FunderChange").withArgs(validator2.address);
            await expect(await bridgeManagementImpl.getFunder()).to.be.equal(validator2.address);
        });

        it("Non-owner fail to start ownership transfer", async function () {
            const { bridgeManagementImpl, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementImpl.connect(validator2).transferOwnership(validator2.address);
            await expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "OwnableUnauthorizedAccount");
        });

        it("Non-owner fail to set relayer", async function () {
            const { bridgeManagementImpl, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementImpl.connect(validator2).setRelayer(validator1.address);
            await expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "OwnableUnauthorizedAccount").withArgs(validator2.address);
        });

        it("Non-owner fail to set governor", async function () {
            const { bridgeManagementImpl, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementImpl.connect(validator2).setGovernor(validator1.address);
            await expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "OwnableUnauthorizedAccount").withArgs(validator2.address);
        });

        it("Non-owner fail to set security guard", async function () {
            const { bridgeManagementImpl, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementImpl.connect(validator2).setSecurityGuard(validator1.address);
            await expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "OwnableUnauthorizedAccount").withArgs(validator2.address);
        });

        it("Non-owner fail to set funder", async function () {
            const { bridgeManagementImpl, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementImpl.connect(validator2).setFunder(validator1.address);
            await expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "OwnableUnauthorizedAccount").withArgs(validator2.address);
        });
    });

    describe("Bridge validator changes", function () {
        it("Add validator and increase threshold", async function () {
            const { bridgeManagementImpl, owner } = await loadFixture(deployBridgeFixture);
            const tx = await bridgeManagementImpl.connect(owner).addValidator(owner.address, true);
            expect(tx).to.emit(bridgeManagementImpl, "ValidatorAdd").withArgs(owner.address, true);
            await expect(await bridgeManagementImpl.getValidators()).to.have.length(8);
            await expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(6);
            await expect((await bridgeManagementImpl.getValidators())[7]).to.be.equal(owner.address);
        });

        it("Add validator and keep current threshold", async function () {
            const { bridgeManagementImpl, owner } = await loadFixture(deployBridgeFixture);
            const tx = await bridgeManagementImpl.connect(owner).addValidator(owner.address, false);
            expect(tx).to.emit(bridgeManagementImpl, "ValidatorAdd").withArgs(owner.address, false);
            await expect(await bridgeManagementImpl.getValidators()).to.have.length(8);
            await expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(5);
            await expect((await bridgeManagementImpl.getValidators())[7]).to.be.equal(owner.address);
        });

        it("Fail adding validator without authorization", async function () {
            const { bridgeManagementImpl, validator1 } = await loadFixture(deployBridgeFixture);
            const tx = bridgeManagementImpl.connect(validator1).addValidator(validator1.address, true);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "OwnableUnauthorizedAccount").withArgs(validator1.address);
        });

        it("Fail adding validator that is already a validator ", async function () {
            const { bridgeManagementImpl, owner, validator1 } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.isValidator(validator1)).to.be.true;
            const tx = bridgeManagementImpl.connect(owner).addValidator(validator1.address, true);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "AlreadyValidator");
        });

        it("Fail adding validator with zero address", async function () {
            const { bridgeManagementImpl, owner } = await loadFixture(deployBridgeFixture);
            const tx1 = bridgeManagementImpl.connect(owner).addValidator(ZeroAddress, true);
            expect(tx1).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidAddress");
            const tx2 = bridgeManagementImpl.connect(owner).addValidator(ZeroAddress, false);
            expect(tx2).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidAddress");
        });

        it("Remove validator and decrease current threshold ", async function () {
            const { bridgeManagementImpl, owner, validator1 } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.isValidator(validator1)).to.be.true;
            expect(await bridgeManagementImpl.getValidators()).to.have.length(7);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(5);

            const tx = await bridgeManagementImpl.connect(owner).removeValidator(0, validator1.address, true);
            expect(tx).to.emit(bridgeManagementImpl, "ValidatorRemove").withArgs(validator1.address, true);
            expect(await bridgeManagementImpl.getValidators()).to.have.length(6);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(4);
        });

        it("Remove validator and keep current threshold ", async function () {
            const { bridgeManagementImpl, owner, validator1 } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.isValidator(validator1)).to.be.true;
            expect(await bridgeManagementImpl.getValidators()).to.have.length(7);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(5);

            const tx = await bridgeManagementImpl.connect(owner).removeValidator(0, validator1.address, false);
            expect(tx).to.emit(bridgeManagementImpl, "ValidatorRemove").withArgs(validator1.address, false);
            expect(await bridgeManagementImpl.getValidators()).to.have.length(6);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(5);
        });

        it("Fail removing validator without authorization ", async function () {
            const { bridgeManagementImpl, validator1, validator2 } = await loadFixture(deployBridgeFixture);
            const tx = bridgeManagementImpl.connect(validator1).removeValidator(1, validator2.address, true);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "OwnableUnauthorizedAccount").withArgs(validator1.address);
        });

        it("Fail removing validator if not a validator with invalid index", async function () {
            const { bridgeManagementImpl, owner } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.isValidator(owner.address)).to.be.false;
            const tx = bridgeManagementImpl.removeValidator(0, owner.address, false);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "NotValidator");
        });

        it("Fail removing validator with index out of bounds", async function () {
            const { bridgeManagementImpl, owner, validator1 } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.getValidators()).to.have.length(7);
            const tx = bridgeManagementImpl.removeValidator(7, validator1.address, false);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "IndexOutOfBounds");
        });

        it("Fail removing validator with incorrect index", async function () {
            const { bridgeManagementImpl, owner, validator4 } = await loadFixture(deployBridgeFixture);
            const index = 3;
            const outOfBoundsIndex = 7;
            const validatorAddress = validator4.address;
            const incorrectIndex = 4;

            expect((await bridgeManagementImpl.connect(owner).getValidators())).to.have.length.lessThan(outOfBoundsIndex + 1);
            expect((await bridgeManagementImpl.connect(owner).getValidators())[index]).to.be.equal(validatorAddress);

            const tx1 = bridgeManagementImpl.connect(owner).removeValidator(incorrectIndex, validatorAddress, false);
            const tx2 = bridgeManagementImpl.connect(owner).removeValidator(incorrectIndex, validatorAddress, true);

            expect(tx1).to.be.revertedWithCustomError(bridgeManagementImpl, "IndexValidatorMismatch");
            expect(tx2).to.be.revertedWithCustomError(bridgeManagementImpl, "IndexValidatorMismatch");
        });

        it("Fail removing validator with incorrect address", async function () {
            const { bridgeManagementImpl, owner, validator1, validator4 } = await loadFixture(deployBridgeFixture);
            const index = 3;
            const validatorAddress = validator4.address;
            const outOfBoundsIndex = 7;
            const incorrectValidatorAddress = validator1.address;

            expect((await bridgeManagementImpl.connect(owner).getValidators())).to.have.length.lessThan(outOfBoundsIndex + 1);
            expect((await bridgeManagementImpl.connect(owner).getValidators())[index]).to.be.equal(validatorAddress);

            const tx1 = bridgeManagementImpl.connect(owner).removeValidator(index, incorrectValidatorAddress, false);
            const tx2 = bridgeManagementImpl.connect(owner).removeValidator(index, incorrectValidatorAddress, true);

            expect(tx1).to.be.revertedWithCustomError(bridgeManagementImpl, "IndexValidatorMismatch");
            expect(tx2).to.be.revertedWithCustomError(bridgeManagementImpl, "IndexValidatorMismatch");
        });

        it("Fail removing validator and keep current threshold if threshold was equal to number of validators", async function () {
            const { bridgeManagementImpl, owner, validator2, validator6, validator7 } = await loadFixture(deployBridgeFixture);
            await bridgeManagementImpl.connect(owner).removeValidator(6, validator7.address, false);
            await bridgeManagementImpl.connect(owner).removeValidator(5, validator6.address, false);

            expect(await bridgeManagementImpl.getValidators()).to.have.length(5);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(5);

            expect((await bridgeManagementImpl.getValidators())[1]).to.be.equal(validator2.address);

            const tx = bridgeManagementImpl.connect(owner).removeValidator(1, validator2.address, false);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidValidatorThreshold");
            // The threshold should still be 5 and validator2 should still be a validator
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(5);
            expect(await bridgeManagementImpl.isValidator(validator2.address)).to.be.true;

            // Verify that the same removal with a decrease of the threshold works
            await bridgeManagementImpl.connect(owner).removeValidator(1, validator2.address, true);
            expect(await bridgeManagementImpl.getValidators()).to.have.length(4);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(4);
            expect(await bridgeManagementImpl.isValidator(validator2.address)).to.be.false;
        });

        it("Fail removing validator if there are only two validators", async function () {
            const { bridgeManagementImpl, owner, validator2, validator3, validator4, validator5, validator6, validator7 } = await loadFixture(deployBridgeFixture);
            await bridgeManagementImpl.connect(owner).removeValidator(6, validator7.address, false);
            await bridgeManagementImpl.connect(owner).removeValidator(5, validator6.address, false);
            await bridgeManagementImpl.connect(owner).removeValidator(4, validator5.address, true);
            await bridgeManagementImpl.connect(owner).removeValidator(3, validator4.address, true);
            await bridgeManagementImpl.connect(owner).removeValidator(2, validator3.address, true);

            expect(await bridgeManagementImpl.getValidators()).to.have.length(2);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(2);

            expect((await bridgeManagementImpl.getValidators())[1]).to.be.equal(validator2.address);

            const tx1 = bridgeManagementImpl.connect(owner).removeValidator(1, validator2.address, true);
            const tx2 = bridgeManagementImpl.connect(owner).removeValidator(1, validator2.address, false);
            expect(tx1).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidValidatorThreshold");
            expect(tx2).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidValidatorThreshold");

            // The threshold should still be 2 and validator2 should still be a validator
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(2);
            expect(await bridgeManagementImpl.isValidator(validator2.address)).to.be.true;
        });

        it("Replace validator", async function () {
            const { bridgeManagementImpl, owner, validator4 } = await loadFixture(deployBridgeFixture);
            const newValidator = owner;
            const index = 3;
            expect(await bridgeManagementImpl.getValidators()).to.have.length(7);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(5);
            expect((await bridgeManagementImpl.getValidators())[index]).to.be.equal(validator4.address);
            expect(await bridgeManagementImpl.isValidator(validator4.address)).to.be.true;
            expect(await bridgeManagementImpl.isValidator(newValidator.address)).to.be.false;

            const tx = await bridgeManagementImpl.connect(owner).replaceValidator(index, validator4.address, newValidator.address);
            expect(tx).to.emit(bridgeManagementImpl, "ValidatorReplace").withArgs(validator4.address, newValidator.address);
            expect(await bridgeManagementImpl.getValidators()).to.have.length(7);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(5);
            expect((await bridgeManagementImpl.getValidators())[index]).to.be.equal(newValidator.address);
            expect(await bridgeManagementImpl.isValidator(validator4.address)).to.be.false;
            expect(await bridgeManagementImpl.isValidator(newValidator.address)).to.be.true;
        });

        it("Fail replacing validator without authorization ", async function () {
            const { bridgeManagementImpl, owner, validator2, validator5 } = await loadFixture(deployBridgeFixture);
            const tx = bridgeManagementImpl.connect(validator5).replaceValidator(1, validator2.address, owner.address);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "OwnableUnauthorizedAccount").withArgs(validator5.address);
        });

        it("Fail replacing validator with zero address", async function () {
            const { bridgeManagementImpl, owner, validator4 } = await loadFixture(deployBridgeFixture);
            const index = 3;
            expect((await bridgeManagementImpl.getValidators())[index]).to.be.equal(validator4.address);
            expect(await bridgeManagementImpl.isValidator(validator4.address)).to.be.true;
            expect(await bridgeManagementImpl.isValidator(ZeroAddress)).to.be.false;

            const tx = bridgeManagementImpl.connect(owner).replaceValidator(4, validator4.address, ZeroAddress);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidAddress");
        });

        it("Fail replacing a validator address that is no validator", async function () {
            const { bridgeManagementImpl, owner, relayer } = await loadFixture(deployBridgeFixture);
            const newValidator = owner;
            const oldValidator = relayer;
            const index = 3;
            expect(await bridgeManagementImpl.isValidator(oldValidator.address)).to.be.false;
            expect(await bridgeManagementImpl.isValidator(newValidator.address)).to.be.false;

            const tx = bridgeManagementImpl.connect(owner).replaceValidator(index, oldValidator.address, newValidator.address);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "NotValidator");
        });

        it("Fail replacing validator with address that is already a validator", async function () {
            const { bridgeManagementImpl, owner, validator2, validator4 } = await loadFixture(deployBridgeFixture);
            const newValidator = validator2;
            const index = 3;
            expect((await bridgeManagementImpl.getValidators())[index]).to.be.equal(validator4.address);
            expect(await bridgeManagementImpl.isValidator(validator4.address)).to.be.true;
            expect(await bridgeManagementImpl.isValidator(newValidator.address)).to.be.true;

            const tx = bridgeManagementImpl.connect(owner).replaceValidator(index, validator4.address, newValidator.address);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "AlreadyValidator");
        });

        it("Fail replacing validator with incorrect index", async function () {
            const { bridgeManagementImpl, owner, validator4 } = await loadFixture(deployBridgeFixture);
            const newValidator = owner;
            const index = 3;
            expect((await bridgeManagementImpl.getValidators())[index]).to.be.equal(validator4.address);
            expect(await bridgeManagementImpl.isValidator(validator4.address)).to.be.true;
            expect(await bridgeManagementImpl.isValidator(newValidator.address)).to.be.false;

            const tx = bridgeManagementImpl.connect(owner).replaceValidator(4, validator4.address, newValidator.address);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "IndexValidatorMismatch");
        });

        it("Fail replacing validator with incorrect address", async function () {
            const { bridgeManagementImpl, owner, validator4, validator5 } = await loadFixture(deployBridgeFixture);
            const newValidator = owner;
            const index = 3;
            expect((await bridgeManagementImpl.getValidators())[index]).to.be.equal(validator4.address);
            expect(await bridgeManagementImpl.isValidator(validator4.address)).to.be.true;
            expect(await bridgeManagementImpl.isValidator(newValidator.address)).to.be.false;

            const tx = bridgeManagementImpl.connect(owner).replaceValidator(3, validator5.address, newValidator.address);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "IndexValidatorMismatch");
        });

        it("Set validator threshold", async function () {
            const { bridgeManagementImpl, owner } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(5);
            expect(await bridgeManagementImpl.getValidators()).to.have.length(7);

            const tx1 = await bridgeManagementImpl.connect(owner).setValidatorThreshold(4);
            expect(tx1).to.emit(bridgeManagementImpl, "ValidatorThresholdChange").withArgs(4);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(4);

            const tx2 = await bridgeManagementImpl.connect(owner).setValidatorThreshold(7);
            expect(tx2).to.emit(bridgeManagementImpl, "ValidatorThresholdChange").withArgs(7);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(7);

            const tx3 = await bridgeManagementImpl.connect(owner).setValidatorThreshold(2);
            expect(tx3).to.emit(bridgeManagementImpl, "ValidatorThresholdChange").withArgs(2);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(2);
        });

        it("Fail setting validator threshold without authorization ", async function () {
            const { bridgeManagementImpl, validator5 } = await loadFixture(deployBridgeFixture);
            const tx = bridgeManagementImpl.connect(validator5).setValidatorThreshold(4);
            expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "OwnableUnauthorizedAccount").withArgs(validator5.address);
        });

        it("Fail setting validator threshold lower than 2", async function () {
            const { bridgeManagementImpl, owner, validator7 } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(5);
            expect(await bridgeManagementImpl.getValidators()).to.have.length(7);

            const tx1 = bridgeManagementImpl.connect(owner).setValidatorThreshold(1);
            expect(tx1).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidValidatorThreshold");
            const tx2 = bridgeManagementImpl.connect(owner).setValidatorThreshold(0);
            expect(tx2).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidValidatorThreshold");
        });

        it("Fail setting validator threshold higher than number of validators", async function () {
            const { bridgeManagementImpl, owner, validator7 } = await loadFixture(deployBridgeFixture);
            expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(5);
            expect(await bridgeManagementImpl.getValidators()).to.have.length(7);

            const tx3 = bridgeManagementImpl.connect(owner).setValidatorThreshold(8);
            expect(tx3).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidValidatorThreshold");
        });
    });

});

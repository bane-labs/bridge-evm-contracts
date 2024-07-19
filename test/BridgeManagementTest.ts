import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ZeroAddress } from "ethers";

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
        const BridgeManagementFactory = (await ethers.getContractFactory("BridgeManagementImpl"));
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

        const bridgeManagementImpl = proxy as BridgeManagementImpl;

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
            expect(await bridgeManagementImpl.getValidator(0)).to.equal(validator1.address);
            expect(await bridgeManagementImpl.getValidator(1)).to.equal(validator2.address);
            expect(await bridgeManagementImpl.getValidator(2)).to.equal(validator3.address);
            expect(await bridgeManagementImpl.getValidator(3)).to.equal(validator4.address);
            expect(await bridgeManagementImpl.getValidator(4)).to.equal(validator5.address);
            expect(await bridgeManagementImpl.getValidator(5)).to.equal(validator6.address);
            expect(await bridgeManagementImpl.getValidator(6)).to.equal(validator7.address);
            await expect(bridgeManagementImpl.getValidator(7)).to.be.revertedWithPanic();
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

        it("Set validators with unique address", async function () {
            const { bridgeManagementImpl, owner } = await loadFixture(deployBridgeFixture);
            const new_validators = [ethers.Wallet.createRandom().address, ethers.Wallet.createRandom().address];
            const tx = await bridgeManagementImpl.connect(owner).setValidators(new_validators, 2);
            await expect(tx).to.emit(bridgeManagementImpl, "ValidatorsChange").withArgs(new_validators, 2);
            await expect(await bridgeManagementImpl.getValidator(0)).to.be.equal(new_validators[0]);
            await expect(await bridgeManagementImpl.getValidator(1)).to.be.equal(new_validators[1]);
            await expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(2);
        });

        it("Set validators multiple times", async function () {
            const { bridgeManagementImpl, owner, validator1, validator2, validator3, validator4 } = await loadFixture(deployBridgeFixture);
            let new_validators = [validator1.address, validator2.address, validator3.address];
            let tx = await bridgeManagementImpl.connect(owner).setValidators(new_validators, 2);
            await expect(tx).to.emit(bridgeManagementImpl, "ValidatorsChange").withArgs(new_validators, 2);
            await expect(await bridgeManagementImpl.getValidator(0)).to.be.equal(validator1.address);
            await expect(await bridgeManagementImpl.getValidator(1)).to.be.equal(validator2.address);
            await expect(await bridgeManagementImpl.getValidator(2)).to.be.equal(validator3.address);
            await expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(2);

            // The 3rd validator address needs to be updated
            new_validators = [validator1.address, validator2.address, validator4.address];
            tx = await bridgeManagementImpl.connect(owner).setValidators(new_validators, 2);
            await expect(tx).to.emit(bridgeManagementImpl, "ValidatorsChange").withArgs(new_validators, 2);
            await expect(await bridgeManagementImpl.getValidator(0)).to.be.equal(validator1.address);
            await expect(await bridgeManagementImpl.getValidator(1)).to.be.equal(validator2.address);
            await expect(await bridgeManagementImpl.getValidator(2)).to.be.equal(validator4.address);
            await expect(await bridgeManagementImpl.getValidatorThreshold()).to.be.equal(2);
        });

        it("Set validators with duplicate addresses", async function () {
            const { bridgeManagementImpl, validator1, validator2, owner } = await loadFixture(deployBridgeFixture);
            const new_validators = [validator1.address, validator1.address, validator2.address];
            const tx = bridgeManagementImpl.connect(owner).setValidators(new_validators, 2);
            await expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidValidatorArray");
        });

        it("Set validators with threshold greater than validators length", async function () {
            const { bridgeManagementImpl, validator1, validator2, owner } = await loadFixture(deployBridgeFixture);
            const new_validators = [validator1.address, validator2.address];
            const tx = bridgeManagementImpl.connect(owner).setValidators(new_validators, 3);
            await expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidValidatorThreshold");
        });

        it("Set validators with empty validators", async function () {
            const { bridgeManagementImpl, owner } = await loadFixture(deployBridgeFixture);
            const tx = bridgeManagementImpl.connect(owner).setValidators([], 2);
            await expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidValidatorArray");
        });

        it("Set validators with zero address validators", async function () {
            const { bridgeManagementImpl, validator1, owner } = await loadFixture(deployBridgeFixture);
            const tx = bridgeManagementImpl.connect(owner).setValidators([validator1.address, ZeroAddress], 2);
            await expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidAddress");
        });

        it("Set validators with threshold set to 0 or 1", async function () {
            const { bridgeManagementImpl, validator1, validator2, owner } = await loadFixture(deployBridgeFixture);
            let tx = bridgeManagementImpl.connect(owner).setValidators([validator1.address, validator2.address], 1);
            await expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidValidatorThreshold");

            tx = bridgeManagementImpl.connect(owner).setValidators([validator1.address, validator2.address], 0);
            await expect(tx).to.be.revertedWithCustomError(bridgeManagementImpl, "InvalidValidatorThreshold");
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

});

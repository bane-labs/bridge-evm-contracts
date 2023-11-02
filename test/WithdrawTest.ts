import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("Bridge contract", function () {
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
        const bridgeContract = await ethers.deployContract("Bridge");
        await bridgeContract.waitForDeployment();
        return {
            bridgeContract,
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

    describe("Withdraw", function () {
        it("withdraw only once", async function () {
            const { bridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            const tx = await bridgeContract.connect(relayer).withdraw(relayer, { value: ethers.parseEther("1") });

            expect(await bridgeContract.withdrawalNonce()).to.be.equal(1);
            const leaf0 = ethers.solidityPacked(["uint32", "address", "uint256"], [1, relayer.address, ethers.parseEther("1")]);
            const expectedHash_leaf0 = ethers.sha256(leaf0);
            expect(await bridgeContract.withdrawalRoot()).to.be.equal(expectedHash_leaf0);
            await expect(tx).to.emit(bridgeContract, "Withdrawal").withArgs(1, relayer.address, relayer.address, ethers.parseEther("1"), expectedHash_leaf0, expectedHash_leaf0);
            expect(await bridgeContract.withdrawalRoot()).to.be.equal(expectedHash_leaf0);
            expect(await bridgeContract.rootMap(0)).to.be.equal(ethers.sha256(leaf0));
            await expect(tx).to.changeEtherBalances([bridgeContract, relayer.address], [ethers.parseEther("1"), -ethers.parseEther("1")]);

        });

        it("withdraw multiple times", async function () {
            const { bridgeContract, relayer, validator1 } = await loadFixture(deployBridgeFixture);

            await bridgeContract.connect(relayer).withdraw(relayer, { value: ethers.parseEther("1") });
            const tx = await bridgeContract.connect(relayer).withdraw(validator1, { value: ethers.parseEther("2") });

            expect(await bridgeContract.withdrawalNonce()).to.be.equal(2);
            const leaf0 = ethers.solidityPacked(["uint32", "address", "uint256"], [1, relayer.address, ethers.parseEther("1")]);
            const leaf1 = ethers.solidityPacked(["uint32", "address", "uint256"], [2, validator1.address, ethers.parseEther("2")]);
            const Hash_leaf0 = ethers.sha256(leaf0);
            const expectedHash_leaf1 = ethers.sha256(leaf1);
            const expect_root = ethers.sha256(ethers.concat([Hash_leaf0, expectedHash_leaf1]));
            expect(await bridgeContract.withdrawalRoot()).to.be.equal(expect_root);
            await expect(tx).to.emit(bridgeContract, "Withdrawal").withArgs(2, relayer.address, validator1.address, ethers.parseEther("2"), expectedHash_leaf1, expect_root);
            expect(await bridgeContract.withdrawalRoot()).to.be.equal(expect_root);
            await expect(tx).to.changeEtherBalances([bridgeContract, relayer.address], [ethers.parseEther("2"), -ethers.parseEther("2")]);

        });

        it("withdraw with the wrong amount", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            await expect(bridgeContract.connect(relayer).withdraw(relayer, { value: ethers.parseEther("0.000000001") })).to.be.revertedWith("Only amounts with 8 non-zero decimals allowed for withdrawal");
        });

        it("withdraw with the amount smaller than minWithdrawalAmount", async function () {
            const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

            await expect(bridgeContract.connect(relayer).withdraw(relayer, { value: ethers.parseEther("0.9") })).to.be.revertedWith("Smaller than minimum withdrawal amount");
        });

    });

});
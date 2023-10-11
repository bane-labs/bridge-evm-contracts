const { expect } = require("chai");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

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
    };
  }

  describe("Deployment", function () {
    it("Should set the right relayer", async function () {
      const { bridgeContract, relayer } = await loadFixture(deployBridgeFixture);

      expect(await bridgeContract.relayer()).to.equal(relayer.address);
    });

    it("Should set the right validators", async function () {
        const {
            bridgeContract,
            validator1,
            validator2,
            validator3,
            validator4,
            validator5,
            validator6,
            validator7
        } = await loadFixture(deployBridgeFixture);

        expect(await bridgeContract.validators(0)).to.equal(validator1.address);
        expect(await bridgeContract.validators(1)).to.equal(validator2.address);
        expect(await bridgeContract.validators(2)).to.equal(validator3.address);
        expect(await bridgeContract.validators(3)).to.equal(validator4.address);
        expect(await bridgeContract.validators(4)).to.equal(validator5.address);
        expect(await bridgeContract.validators(5)).to.equal(validator6.address);
        expect(await bridgeContract.validators(6)).to.equal(validator7.address);
        await expect(bridgeContract.validators(7)).to.be.revertedWithoutReason();
    });
  });

  // Todo: Add tests for withdrawal merkle tree computation
  
  // Todo: Add tests for deposit merkle tree verification and transfer

});

// const { expect } = require("chai");
// const {
//   loadFixture,
// } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

// describe("Bridge contract", function () {
//   async function deployTokenFixture() {
//     const [owner, addr1, addr2] = await ethers.getSigners();
//     const hardhatToken = await ethers.deployContract("Token");
//     await hardhatToken.waitForDeployment();
//     return { hardhatToken, owner, addr1, addr2 };
//   }

//   describe("Deployment", function () {
//     it("Should set the right owner", async function () {
//       const { hardhatToken, owner } = await loadFixture(deployTokenFixture);

//       expect(await hardhatToken.owner()).to.equal(owner.address);
//     });

//     it("Should assign the total supply of tokens to the owner", async function () {
//       const { hardhatToken, owner } = await loadFixture(deployTokenFixture);
//       const ownerBalance = await hardhatToken.balanceOf(owner.address);
//       expect(await hardhatToken.totalSupply()).to.equal(ownerBalance);
//     });
//   });
// });

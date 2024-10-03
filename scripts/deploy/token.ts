import { ethers } from "hardhat";
import { Wallet } from "ethers";
import { TestToken } from "../../typechain-types/contracts/tests";

export async function deployTokenContract(deployer: Wallet): Promise<TestToken> {
    console.log("\n#####################################################################");
    console.log("##################### Token Contract Deployment #####################");
    console.log("#####################################################################");
    const tokenFactory = (await ethers.getContractFactory("TestToken")).connect(deployer);
    const tokenContract = await tokenFactory.deploy("TestToken", "TT");
    await tokenContract.waitForDeployment();
    const neoToken = tokenContract as TestToken
    console.log("\n# Deployment");
    console.log("Token Address: ", await neoToken.getAddress());
    console.log("Minted Tokens: ", ethers.formatEther(await neoToken.totalSupply()));
    return neoToken;
}

import { ethers } from "hardhat";
import { Wallet } from "ethers";
import { TestToken } from "../../typechain-types/contracts/tests";
import { MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "../utils/constants";

export async function deployTokenContract(deployer: Wallet): Promise<TestToken> {
    console.log("\n#####################################################################");
    console.log("##################### Token Contract Deployment #####################");
    console.log("#####################################################################");
    const tokenFactory = (await ethers.getContractFactory("TestToken")).connect(deployer);
    const tokenContract = await tokenFactory.deploy("TestToken", "TTT", { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS });
    await tokenContract.waitForDeployment();
    const token = await ethers.getContractAt("TestToken", await tokenContract.getAddress());

    console.log("\n# Deployment");
    console.log("Token Address: ", await token.getAddress());
    console.log("Minted Tokens: ", ethers.formatEther(await token.totalSupply()));
    return token;
}

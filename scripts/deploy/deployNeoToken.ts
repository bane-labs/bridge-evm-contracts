import { ethers, upgrades } from "hardhat";
import { Wallet } from "ethers";
import { NeoToken } from "../../typechain-types/contracts/token/";
import { MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "../utils/constants";
import { fundIfLocalNetwork } from "../utils/network";
import { getPersonalWallet, getValdiator02 } from "../utils/wallet";

export async function deployNeoTokenContract(deployer: Wallet): Promise<NeoToken> {
    console.log("\n#####################################################################");
    console.log("################### NeoToken Contract Deployment ###################");
    console.log("#####################################################################");

    const NeoTokenFactory = (await ethers.getContractFactory("NeoToken")).connect(deployer);
    const neoTokenProxy = await upgrades.deployProxy(NeoTokenFactory, [], { kind: "uups", unsafeAllow: ["constructor"], txOverrides: { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS } });
    await neoTokenProxy.waitForDeployment();
    const neoToken = await ethers.getContractAt("NeoToken", await neoTokenProxy.getAddress());

    console.log("\nDeployment");
    console.log("Neo Token Address: ", await neoToken.getAddress());
    console.log("Minted Tokens: ", ethers.formatEther(await neoToken.totalSupply()));
    return neoToken;
}

async function main() {
    const deployer = getPersonalWallet(ethers.provider);
    await fundIfLocalNetwork([deployer.address]);
    const neoToken = await deployNeoTokenContract(deployer);
    console.log("\nNeoToken Contract Deployment Completed");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

import { ethers } from "hardhat";
import { deployTokenContract } from "./deploy/token";
import { fundIfLocalNetwork } from "./utils/network";
import { getDeployer, getOwner } from "./utils/wallet";

async function main() {
    const deployer = getDeployer(ethers.provider);
    const governor = getOwner(ethers.provider);
    await fundIfLocalNetwork([deployer.address, governor.address]);
    await deployTokenContract(deployer);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

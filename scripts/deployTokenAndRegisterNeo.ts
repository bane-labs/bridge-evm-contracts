import { ethers } from "hardhat";
import { deployTokenContract } from "./deploy/token";
import { getBridgeFromEnv, N3_NEO_ADDRESS } from "./utils/addresses";
import { TokenExecutionType } from "./utils/constants";
import { fundIfLocalNetwork } from "./utils/network";
import { registerToken } from "./utils/registration";
import { getDeployer, getOwner } from "./utils/wallet";

async function main() {
    const deployer = getDeployer(ethers.provider);
    const governor = getOwner(ethers.provider);
    await fundIfLocalNetwork([deployer.address, governor.address]);
    const bridge = await getBridgeFromEnv(ethers.provider);
    const token = await deployTokenContract(deployer);
    await registerToken(bridge, governor, token, TokenExecutionType.NEO, N3_NEO_ADDRESS);
    await token.connect(deployer).transfer(await bridge.getAddress(), ethers.parseEther("10000"));
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

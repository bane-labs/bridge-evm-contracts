import { ethers } from "hardhat";
import { deployTokenContract } from "../deploy/token";
import { getBridgeFromEnv, N3_NEO_ADDRESS } from "../utils/addresses";
import { fundIfLocalNetwork } from "../utils/network";
import { registerTokenWithScalingFactor } from "../utils/registration";
import { getDeployer, getGovernor } from "../utils/wallet";

async function main() {
    const deployer = getDeployer(ethers.provider);
    const governor = getGovernor(ethers.provider);
    await fundIfLocalNetwork([deployer.address, governor.address]);
    const bridge = await getBridgeFromEnv(ethers.provider);
    const token = await deployTokenContract(deployer);
    await registerTokenWithScalingFactor(bridge, governor, token, N3_NEO_ADDRESS, 18n);
    await token.connect(deployer).transfer(await bridge.getAddress(), ethers.parseEther("10000"));
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

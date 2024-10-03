import { ethers } from "hardhat";
import { deployBridgeContracts } from "./deploy/bridge";
import { deployTokenContract } from "./deploy/token";
import { getBridgeFromEnv, N3_NEO_ADDRESS } from "./utils/addresses";
import { TokenExecutionType } from "./utils/constants";
import { registerToken } from "./utils/registration";
import { getDeployer, getOwner } from "./utils/wallet";
import { fundIfLocalNetwork } from "./utils/network";
import { fundAddress } from "./utils/funding";

async function main() {
    const deployer = getDeployer(ethers.provider);
    const governor = getOwner(ethers.provider);
    fundIfLocalNetwork(deployer.address);
    fundIfLocalNetwork(governor.address);
    const bridge = await getBridgeFromEnv(ethers.provider);
    const token = await deployTokenContract(deployer);
    await registerToken(bridge, governor, token, TokenExecutionType.NEO, N3_NEO_ADDRESS);
    await token.connect(deployer).transfer(await bridge.getAddress(), ethers.parseEther("10000"));
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

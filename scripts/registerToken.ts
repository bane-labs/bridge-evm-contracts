import { ethers } from "hardhat";
import { getN3TokenAddressFromEnv, getBridgeFromEnv, getNeoXTokenFromEnv } from "./utils/addresses";
import { MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "./utils/constants";
import { fundIfLocalNetwork } from "./utils/network";
import { registerToken } from "./utils/registration";
import { getDeployer, getOwner } from "./utils/wallet";

async function main() {
    const deployer = getDeployer(ethers.provider);
    const governor = getOwner(ethers.provider);
    await fundIfLocalNetwork([deployer.address, governor.address]);
    const bridge = await getBridgeFromEnv(ethers.provider);
    const token = await getNeoXTokenFromEnv();
    await registerToken(bridge, governor, token, getN3TokenAddressFromEnv());
    await token.connect(deployer).transfer(await bridge.getAddress(), ethers.parseEther("10000"), { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

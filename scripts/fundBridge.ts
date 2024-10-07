import { ethers } from "hardhat";
import { deployBridgeContracts } from "./deploy/bridge";
import { getBridgeFromEnv } from "./utils/addresses";
import { fundIfLocalNetwork, isLocalNetwork } from "./utils/network";
import { getDeployer, getOwner } from "./utils/wallet";
import { fundAddress } from "./utils/funding";

async function main() {
    // Using the deployer account since it'll have some gas balance that can be used to withdraw
    const deployer = getDeployer(ethers.provider);
    const funder = getOwner(ethers.provider);
    await fundIfLocalNetwork([deployer.address, funder.address]);

    var bridge;
    if (isLocalNetwork(await ethers.provider.getNetwork())) {
        bridge = await deployBridgeContracts();
    } else {
        bridge = await getBridgeFromEnv(ethers.provider);
    }
    await fundAddress(funder, await bridge.getAddress(), ethers.parseEther("100"));
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

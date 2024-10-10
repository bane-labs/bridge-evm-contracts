import { ethers } from "hardhat";
import { deployBridgeContracts } from "./deploy/bridge";
import { deployTokenContract } from "./deploy/token";
import { N3_NEO_ADDRESS } from "./utils/addresses";
import { registerToken, registerTokenWithScalingFactor } from "./utils/registration";
import { getDeployer, getOwner } from "./utils/wallet";

async function main() {
    const deployer = getDeployer(ethers.provider);
    const bridgeOwner = getOwner(ethers.provider);
    const funder = bridgeOwner;
    const governor = bridgeOwner;
    const bridge = await deployBridgeContracts();

    const token = await deployTokenContract(deployer);

    await token.connect(deployer).transfer(await bridge.getAddress(), ethers.parseEther("10000"));
    await registerTokenWithScalingFactor(bridge, governor, token, N3_NEO_ADDRESS, 18n);

    const balanceFunder = await token.balanceOf(await funder.getAddress());
    const balanceBridge = await token.balanceOf(await bridge.getAddress());
    console.log("\n# Token Balances");
    console.log("Funder Balance: ", ethers.formatEther(balanceFunder));
    console.log("Bridge Balance: ", ethers.formatEther(balanceBridge));
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

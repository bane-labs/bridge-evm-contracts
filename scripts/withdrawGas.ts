import { ethers } from "hardhat";
import { deployBridgeContracts } from "./deploy/bridge";
import { getBridgeFromEnv } from "./utils/addresses";
import { MAX_FEE_PER_GAS } from "./utils/constants";
import { fundIfLocalNetwork, isLocalNetwork } from "./utils/network";
import { getDeployer } from "./utils/wallet";

async function main() {
    // Using the deployer account since it'll have some gas balance that can be used to withdraw
    const sender = getDeployer(ethers.provider);
    await fundIfLocalNetwork([sender.address]);

    var bridge;
    if (isLocalNetwork(await ethers.provider.getNetwork())) {
        bridge = await deployBridgeContracts();
    } else {
        bridge = await getBridgeFromEnv(ethers.provider);
    }

    const amount = ethers.parseEther("10");
    const withdrawTx = await bridge.connect(sender).withdrawGas(sender.address, amount, { value: amount, maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_FEE_PER_GAS });

    const receipt = await withdrawTx.wait();
    console.log("Withdraw Gas Transaction Receipt: ", receipt);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

import { ethers } from "hardhat";
import { Network } from "ethers";
import { HARDHAT_LOCAL_NETWORK_CHAIN_ID, HARDHAT_DEFAULT_PROVIDER_NETWORK_CHAIN_ID, NEOX_TESTNET_CHAIN_ID } from "./constants";
import { fundAddress } from "./funding";

export function isLocalNetwork(network: Network) {
    return network.chainId === HARDHAT_LOCAL_NETWORK_CHAIN_ID || network.chainId === HARDHAT_DEFAULT_PROVIDER_NETWORK_CHAIN_ID;
}

export async function fundIfLocalNetwork(addresses: string[]) {
    const network = await ethers.provider.getNetwork();
    if (isLocalNetwork(network)) {
        console.log("\n# Funding");
        const [signer01] = await ethers.getSigners();
        for (const address of addresses) {
            await fundAddress(signer01, address, ethers.parseEther("100"));
        }
    }
}

export async function printNetworkConfiguration() {
    const network = await ethers.provider.getNetwork();
    const chainId = network.chainId;
    const localNetwork = chainId === HARDHAT_LOCAL_NETWORK_CHAIN_ID || chainId === HARDHAT_DEFAULT_PROVIDER_NETWORK_CHAIN_ID;
    console.log("\n# Network Configuration");
    if (localNetwork) {
        console.log("Network:                              Local Hardhat Network");
        console.log("Chain Id:                            ", chainId.toString());
    } else if (network.name) {
        console.log('Network:                              ', network.name);
        console.log('Chain ID:                             ', chainId.toString());
    }
}

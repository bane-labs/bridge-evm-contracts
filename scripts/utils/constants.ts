import { ethers } from "hardhat";

export const HARDHAT_LOCAL_NETWORK_CHAIN_ID = 1n;
export const HARDHAT_DEFAULT_PROVIDER_NETWORK_CHAIN_ID = 31337n;
export const NEOX_TESTNET_CHAIN_ID = 12227332n;
export const MAX_FEE_PER_GAS = ethers.parseUnits("41", "gwei");  // maxGasTip
export const MAX_PRIORITY_FEE_PER_GAS = ethers.parseUnits("20", "gwei"); // maxGasFee

export function printFeeConfiguration() {
    console.log("Max Priority Fee Per Gas (gasFeeCap):", ethers.formatUnits(MAX_PRIORITY_FEE_PER_GAS, "gwei"), "gwei");
    console.log("Max Fee Per Gas (gasTipCap):         ", ethers.formatUnits(MAX_FEE_PER_GAS, "gwei"), "gwei");
}

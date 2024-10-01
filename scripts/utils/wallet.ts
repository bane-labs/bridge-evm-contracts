import { ethers } from "hardhat";
import { vars } from "hardhat/config";
import { Provider } from "ethers";
import fs from "fs";

// For testing purposes, the owner is also used as the deployer, governor, security guart, and funder.
export const DEPLOYER_PASSWORD = vars.has("BRIDGE_DEPLOYER_PASSWORD") ? vars.get("BRIDGE_DEPLOYER_PASSWORD") : "";
export const OWNER_PASSWORD = vars.has("BRIDGE_OWNER_PASSWORD") ? vars.get("BRIDGE_OWNER_PASSWORD") : "";
export const RELAYER_PASSWORD = vars.has("BRIDGE_RELAYER_PASSWORD") ? vars.get("BRIDGE_RELAYER_PASSWORD") : "";
export const VALIDATOR01_PASSWORD = vars.has("BRIDGE_VALIDATOR01_PASSWORD") ? vars.get("BRIDGE_VALIDATOR01_PASSWORD") : "";
export const VALIDATOR02_PASSWORD = vars.has("BRIDGE_VALIDATOR02_PASSWORD") ? vars.get("BRIDGE_VALIDATOR02_PASSWORD") : "";

export function getDeployer(provider: Provider) {
    return getWalletFromFile("wallets/deployer.json", DEPLOYER_PASSWORD).connect(provider);
}

export function getOwner(provider: Provider) {
    return getWalletFromFile("wallets/owner.json", OWNER_PASSWORD)
}

export function getRelayer() {
    return getWalletFromFile("wallets/relayer.json", RELAYER_PASSWORD);
}

export function getValidator01() {
    return getWalletFromFile("wallets/validator01.json", VALIDATOR01_PASSWORD);
}

export function getValdiator02() {
    return getWalletFromFile("wallets/validator02.json", VALIDATOR02_PASSWORD);
}

function getWalletFromFile(filename: string, password: string) {
    var buf = fs.readFileSync(filename);
    return ethers.Wallet.fromEncryptedJsonSync(buf.toString(), password).connect(ethers.provider);
}

function getAddressFromWalletFile(filename: string) {
    const read = fs.readFileSync(filename, "utf8");
    const wallet = JSON.parse(read);
    return wallet.address;
}
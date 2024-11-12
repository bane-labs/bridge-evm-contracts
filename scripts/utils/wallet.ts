import { Wallet } from "ethers";
import { Provider } from "ethers";
import fs from "fs";
import { ethers } from "hardhat";
import { vars } from "hardhat/config";

// For testing purposes, the owner is also used as the deployer, governor, security guart, and funder.
export const DEPLOYER_PASSWORD = vars.has("BRIDGE_DEPLOYER_PASSWORD") ? vars.get("BRIDGE_DEPLOYER_PASSWORD") : "";
export const OWNER_PASSWORD = vars.has("BRIDGE_OWNER_PASSWORD") ? vars.get("BRIDGE_OWNER_PASSWORD") : "";
export const RELAYER_PASSWORD = vars.has("BRIDGE_RELAYER_PASSWORD") ? vars.get("BRIDGE_RELAYER_PASSWORD") : "";
export const VALIDATOR01_PASSWORD = vars.has("BRIDGE_VALIDATOR01_PASSWORD") ? vars.get("BRIDGE_VALIDATOR01_PASSWORD") : "";
export const VALIDATOR02_PASSWORD = vars.has("BRIDGE_VALIDATOR02_PASSWORD") ? vars.get("BRIDGE_VALIDATOR02_PASSWORD") : "";

export const PERSONAL_WALLET_PASSWORD = vars.has("PERSONAL_WALLET_PASSWORD") ? vars.get("PERSONAL_WALLET_PASSWORD") : "";
export const PERSONAL_WALLET_FILENAME = vars.has("PERSONAL_WALLET_FILENAME") ? vars.get("PERSONAL_WALLET_FILENAME") : "personal-wallet";

export function getPersonalWallet(provider: Provider): Wallet {
    return getWalletFromFile("wallets/" + PERSONAL_WALLET_FILENAME + ".json", PERSONAL_WALLET_PASSWORD).connect(provider);
}

export function getDeployer(provider: Provider): Wallet {
    return getWalletFromFile("wallets/deployer.json", DEPLOYER_PASSWORD).connect(provider);
}

export function getOwner(provider: Provider): Wallet {
    return getWalletFromFile("wallets/owner.json", OWNER_PASSWORD).connect(provider);
}

export function getRelayer(): Wallet {
    return getWalletFromFile("wallets/relayer.json", RELAYER_PASSWORD);
}

export function getValidator01(): Wallet {
    return getWalletFromFile("wallets/validator01.json", VALIDATOR01_PASSWORD);
}

export function getValdiator02(): Wallet {
    return getWalletFromFile("wallets/validator02.json", VALIDATOR02_PASSWORD);
}

function getWalletFromFile(filename: string, password: string): Wallet {
    var buf = fs.readFileSync(filename);
    return ethers.Wallet.fromEncryptedJsonSync(buf.toString(), password).connect(ethers.provider) as Wallet;
}

function getAddressFromWalletFile(filename: string): Wallet {
    const read = fs.readFileSync(filename, "utf8");
    const wallet = JSON.parse(read);
    return wallet.address;
}

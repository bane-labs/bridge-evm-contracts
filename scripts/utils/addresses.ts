import { Provider } from "ethers";
import { ethers } from "hardhat";
import { vars } from "hardhat/config";
import { TestBridge, TestBridgeManagement, TestMessageBridge, TestToken } from "../../typechain-types/contracts/tests";
import { MessageBridge } from "../../typechain-types";

export const BRIDGE_ADDRESS = vars.has("BRIDGE_ADDRESS") ? vars.get("BRIDGE_ADDRESS") : "";
export const MESSAGE_BRIDGE_ADDRESS = vars.has("MESSAGE_BRIDGE_ADDRESS") ? vars.get("MESSAGE_BRIDGE_ADDRESS") : "";
export const MANAGEMENT_ADDRESS = vars.has("MANAGEMENT_ADDRESS") ? vars.get("MANAGEMENT_ADDRESS") : "";
export const N3_NEO_ADDRESS = "0xef4073a0f2b305a38ec4050e4d3d28bc40ea63f5";
export const N3_TOKEN_ADDRESS = vars.has("N3_TOKEN_ADDRESS") ? vars.get("N3_TOKEN_ADDRESS") : "";
export const N3_DEFAULT_RECIPIENT_ADDRESS = vars.has("N3_DEFAULT_RECIPIENT_ADDRESS") ? vars.get("N3_DEFAULT_RECIPIENT_ADDRESS") : "";
export const NEOX_TOKEN_ADDRESS = vars.has("NEOX_TOKEN_ADDRESS") ? vars.get("NEOX_TOKEN_ADDRESS") : "";

export async function getBridgeFromEnv(provider: Provider): Promise<TestBridge> {
    if (BRIDGE_ADDRESS === "") {
        throw new Error("BRIDGE_ADDRESS is not set in the environment");
    }
    return (await ethers.getContractAt("TestBridge", BRIDGE_ADDRESS)) as TestBridge;
}

export async function getManagementFromEnv(provider: Provider): Promise<TestBridgeManagement> {
    if (MANAGEMENT_ADDRESS === "") {
        throw new Error("MANAGEMENT_ADDRESS is not set in the environment");
    }
    return (await ethers.getContractAt("TestBridgeManagement", MANAGEMENT_ADDRESS)) as TestBridgeManagement;
}

export async function getMessageBridgeFromEnv(): Promise<MessageBridge> {
    if (MESSAGE_BRIDGE_ADDRESS === "") {
        throw new Error("MESSAGE_BRIDGE_ADDRESS is not set in the environment");
    }
    return (await ethers.getContractAt("TestMessageBridge", MESSAGE_BRIDGE_ADDRESS)) as TestMessageBridge;
}

export function getN3DefaultRecipientFromEnv(): string {
    return N3_DEFAULT_RECIPIENT_ADDRESS;
}

export function getN3TokenAddressFromEnv(): string {
    if (N3_TOKEN_ADDRESS === "") {
        throw new Error("N3_TOKEN_ADDRESS is not set in the environment");
    }
    return N3_TOKEN_ADDRESS;
}

export function defaultN3TokenAddress(): string {
    return N3_NEO_ADDRESS;
}

export async function getNeoXTokenFromEnv(): Promise<TestToken> {
    return await (ethers.getContractAt("TestToken", NEOX_TOKEN_ADDRESS) as Promise<TestToken>);
}

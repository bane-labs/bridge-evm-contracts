import fs from "fs";
import path from "path";
import { ethers } from "ethers";
import { AccountConfig, DeploymentConfig, NetworkConfig, OpsConfig } from "./types";

const REPO_ROOT = path.resolve(__dirname, "../..");

const NETWORK_ALIASES: Record<string, string> = {
  neoxTestnet: "neox-testnet",
  neoxMainnet: "neox-mainnet",
  neoxDevnet: "neox-devnet",
  localhost: "local",
  hardhat: "local"
};

export function normalizeNetworkName(input: string): string {
  return NETWORK_ALIASES[input] ?? input;
}

export function loadOpsConfig(networkInput: string): OpsConfig {
  const networkName = normalizeNetworkName(networkInput);
  const networkPath = configPath("networks", `${networkName}.json`);
  const deploymentPath = configPath("deployments", `${networkName}.json`);
  const deploymentOverridePath = configPath("deployments", `${networkName}.local.json`);
  const accountsPath = configPath("accounts", `${networkName}.json`);

  const network = readJson<NetworkConfig>(networkPath, true);
  validateNetworkConfig(network, networkPath);

  const baseDeployment = readJson<DeploymentConfig>(deploymentPath, false) ?? emptyDeployment(networkName);
  validateDeploymentConfig(baseDeployment, deploymentPath);

  const overrideDeployment = readJson<DeploymentConfig>(deploymentOverridePath, false);
  if (overrideDeployment) validateDeploymentConfig(overrideDeployment, deploymentOverridePath);
  const deployment = overrideDeployment ? mergeDeployment(baseDeployment, overrideDeployment) : baseDeployment;

  const accounts = readJson<AccountConfig>(accountsPath, false) ?? { network: networkName, accounts: {} };

  return {
    networkName,
    network,
    deployment,
    accounts,
    sources: {
      network: relative(networkPath),
      deployment: fs.existsSync(deploymentPath) ? relative(deploymentPath) : undefined,
      deploymentOverride: fs.existsSync(deploymentOverridePath) ? relative(deploymentOverridePath) : undefined,
      accounts: fs.existsSync(accountsPath) ? relative(accountsPath) : undefined
    }
  };
}

export function resolveBridgeAddress(config: OpsConfig, override?: string): string {
  return resolveAddress("bridge", override ?? config.deployment.contracts.bridge);
}

export function resolveTokenAddress(config: OpsConfig, token: string): string {
  if (ethers.isAddress(token)) return token;
  const tokenConfig = config.deployment.tokens?.[token];
  if (!tokenConfig?.neoX) {
    throw new Error(`Token alias "${token}" is not configured for ${config.networkName}`);
  }
  return resolveAddress(`token alias "${token}"`, tokenConfig.neoX);
}

function resolveAddress(label: string, value?: string): string {
  if (!value) {
    throw new Error(`${label} address is not configured. Set it in config/deployments/<network>.json, create a .local.json override, or pass an explicit flag.`);
  }
  if (!ethers.isAddress(value)) throw new Error(`${label} address is invalid: ${value}`);
  return value;
}

function mergeDeployment(base: DeploymentConfig, override: DeploymentConfig): DeploymentConfig {
  return {
    network: override.network || base.network,
    contracts: { ...base.contracts, ...definedOnly(override.contracts) },
    tokens: { ...(base.tokens ?? {}), ...(override.tokens ?? {}) }
  };
}

function definedOnly<T extends Record<string, unknown>>(value: T): Partial<T> {
  return Object.fromEntries(Object.entries(value).filter(([, v]) => v !== undefined && v !== "")) as Partial<T>;
}

function emptyDeployment(network: string): DeploymentConfig {
  return { network, contracts: {}, tokens: {} };
}

function validateNetworkConfig(config: NetworkConfig, filePath: string): void {
  if (!config.name) throw new Error(`${relative(filePath)} is missing name`);
  if (!Number.isInteger(config.chainId) || config.chainId <= 0) throw new Error(`${relative(filePath)} has invalid chainId`);
  if (!config.rpcUrl) throw new Error(`${relative(filePath)} is missing rpcUrl`);
}

function validateDeploymentConfig(config: DeploymentConfig, filePath: string): void {
  for (const [name, value] of Object.entries(config.contracts ?? {})) {
    if (value && !ethers.isAddress(value)) throw new Error(`${relative(filePath)} has invalid ${name} address: ${value}`);
  }
  for (const [alias, token] of Object.entries(config.tokens ?? {})) {
    if (token.neoX && !ethers.isAddress(token.neoX)) throw new Error(`${relative(filePath)} has invalid ${alias}.neoX address: ${token.neoX}`);
    if (token.neoN3 && !ethers.isAddress(token.neoN3)) throw new Error(`${relative(filePath)} has invalid ${alias}.neoN3 address: ${token.neoN3}`);
  }
}

function readJson<T>(filePath: string, required: true): T;
function readJson<T>(filePath: string, required: false): T | undefined;
function readJson<T>(filePath: string, required: boolean): T | undefined {
  if (!fs.existsSync(filePath)) {
    if (required) throw new Error(`Missing required config file: ${relative(filePath)}`);
    return undefined;
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8")) as T;
}

function configPath(...parts: string[]): string {
  return path.join(REPO_ROOT, "config", ...parts);
}

function relative(filePath: string): string {
  return path.relative(REPO_ROOT, filePath);
}

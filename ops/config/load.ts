import fs from "fs";
import path from "path";
import { ethers } from "ethers";
import { AccountConfig, DeploymentConfig, NetworkConfig, OpsConfig } from "./types";

const REPO_ROOT = path.resolve(__dirname, "..", "..");

type NetworkConfigOverride = Pick<NetworkConfig, "name"> & Partial<Omit<NetworkConfig, "name" | "gas">> & {
  gas?: NetworkConfig["gas"];
};

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
  validateNetworkName(networkName);
  const networkPath = configPath("networks", `${networkName}.json`);
  const networkOverridePath = configPath("networks", `${networkName}.local.json`);
  const deploymentPath = configPath("deployments", `${networkName}.json`);
  const deploymentOverridePath = configPath("deployments", `${networkName}.local.json`);
  const accountsPath = configPath("accounts", `${networkName}.json`);

  const baseNetwork = readJson<NetworkConfig>(networkPath, true);
  validateNetworkConfig(baseNetwork, networkPath, networkName);

  const overrideNetwork = readJson<NetworkConfigOverride>(networkOverridePath, false);
  if (overrideNetwork) validateNetworkOverrideConfig(overrideNetwork, networkOverridePath, networkName);
  const network = overrideNetwork ? mergeNetwork(baseNetwork, overrideNetwork) : baseNetwork;
  if (overrideNetwork) validateNetworkConfig(network, networkOverridePath, networkName);

  const baseDeploymentFile = readJson<DeploymentConfig>(deploymentPath, false);
  const baseDeployment = baseDeploymentFile ?? emptyDeployment(networkName);
  validateDeploymentConfig(baseDeployment, deploymentPath, networkName);

  const overrideDeployment = readJson<DeploymentConfig>(deploymentOverridePath, false);
  if (overrideDeployment) validateDeploymentConfig(overrideDeployment, deploymentOverridePath, networkName);
  const deployment = overrideDeployment ? mergeDeployment(baseDeployment, overrideDeployment) : baseDeployment;

  const accountsFile = readJson<AccountConfig>(accountsPath, false);
  const accounts = accountsFile ?? { network: networkName, accounts: {} };
  validateAccountConfig(accounts, accountsPath, networkName);

  return {
    networkName,
    network,
    deployment,
    accounts,
    sources: {
      network: relative(networkPath),
      networkOverride: overrideNetwork !== undefined ? relative(networkOverridePath) : undefined,
      deployment: baseDeploymentFile !== undefined ? relative(deploymentPath) : undefined,
      deploymentOverride: overrideDeployment !== undefined ? relative(deploymentOverridePath) : undefined,
      accounts: accountsFile !== undefined ? relative(accountsPath) : undefined
    }
  };
}

export function resolveBridgeAddress(config: OpsConfig, override?: string): string {
  return resolveAddress("bridge", override ?? config.deployment.contracts.bridge);
}

export function resolveMessageBridgeAddress(config: OpsConfig, override?: string): string {
  return resolveAddress("messageBridge", override ?? config.deployment.contracts.messageBridge);
}

export function resolveTokenAddress(config: OpsConfig, token: string): string {
  if (ethers.isAddress(token)) return token;
  const tokenConfig = config.deployment.tokens?.[token];
  if (!tokenConfig?.neoX) {
    throw new Error(`Token alias "${token}" is not configured for ${config.networkName}`);
  }
  return resolveAddress(`token alias "${token}"`, tokenConfig.neoX);
}

function mergeNetwork(base: NetworkConfig, override: NetworkConfigOverride): NetworkConfig {
  const gas = base.gas === undefined && override.gas === undefined
    ? undefined
    : { ...(base.gas ?? {}), ...(override.gas ?? {}) };

  return {
    name: override.name ?? base.name,
    hardhatNetwork: override.hardhatNetwork ?? base.hardhatNetwork,
    chainId: override.chainId ?? base.chainId,
    rpcUrl: override.rpcUrl ?? base.rpcUrl,
    gas
  };
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

function validateNetworkName(networkName: string): void {
  if (!/^[a-z0-9][a-z0-9-]*$/.test(networkName)) {
    throw new Error(`Invalid network name "${networkName}". Use lowercase letters, numbers, and hyphens only.`);
  }
}

function validateNetworkConfig(config: NetworkConfig, filePath: string, expectedNetwork: string): void {
  if (!config.name) throw new Error(`${relative(filePath)} is missing name`);
  if (config.name !== expectedNetwork) {
    throw new Error(`${relative(filePath)} declares network "${config.name}" but "${expectedNetwork}" was requested`);
  }
  if (!Number.isInteger(config.chainId) || config.chainId <= 0) throw new Error(`${relative(filePath)} has invalid chainId`);
  if (!config.rpcUrl) throw new Error(`${relative(filePath)} is missing rpcUrl`);
}

function validateNetworkOverrideConfig(config: NetworkConfigOverride, filePath: string, expectedNetwork: string): void {
  if (!config.name) throw new Error(`${relative(filePath)} is missing name`);
  if (config.name !== expectedNetwork) {
    throw new Error(`${relative(filePath)} declares network "${config.name}" but "${expectedNetwork}" was requested`);
  }
}

function validateDeploymentConfig(config: DeploymentConfig, filePath: string, expectedNetwork: string): void {
  if (!config.network) throw new Error(`${relative(filePath)} is missing network`);
  if (config.network !== expectedNetwork) {
    throw new Error(`${relative(filePath)} declares network "${config.network}" but "${expectedNetwork}" was requested`);
  }
  for (const [name, value] of Object.entries(config.contracts ?? {})) {
    if (value && !ethers.isAddress(value)) throw new Error(`${relative(filePath)} has invalid ${name} address: ${value}`);
  }
  for (const [alias, token] of Object.entries(config.tokens ?? {})) {
    if (token.neoX && !ethers.isAddress(token.neoX)) throw new Error(`${relative(filePath)} has invalid ${alias}.neoX address: ${token.neoX}`);
    if (token.neoN3 && !ethers.isAddress(token.neoN3)) throw new Error(`${relative(filePath)} has invalid ${alias}.neoN3 address: ${token.neoN3}`);
  }
}

function validateAccountConfig(config: AccountConfig, filePath: string, expectedNetwork: string): void {
  if (!config.network) throw new Error(`${relative(filePath)} is missing network`);
  if (config.network !== expectedNetwork) {
    throw new Error(`${relative(filePath)} declares network "${config.network}" but "${expectedNetwork}" was requested`);
  }
  for (const [name, account] of Object.entries(config.accounts ?? {})) {
    if (account.type === "keystore") {
      if (!account.path) throw new Error(`${relative(filePath)} account "${name}" is missing path`);
      if (account.passwordEnv !== undefined && !account.passwordEnv) {
        throw new Error(`${relative(filePath)} account "${name}" has an empty passwordEnv`);
      }
      continue;
    }
    if (account.type === "privateKeyEnv") {
      if (!account.env) throw new Error(`${relative(filePath)} account "${name}" is missing env`);
      continue;
    }
    throw new Error(`${relative(filePath)} account "${name}" has unsupported type`);
  }
}

function readJson<T>(filePath: string, required: true): T;
function readJson<T>(filePath: string, required: false): T | undefined;
function readJson<T>(filePath: string, required: boolean): T | undefined {
  if (!fs.existsSync(filePath)) {
    if (required) throw new Error(`Missing required config file: ${relative(filePath)}`);
    return undefined;
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(fs.readFileSync(filePath, "utf8")) as unknown;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`${relative(filePath)} contains invalid JSON: ${message}`);
  }
  if (!isJsonObject(parsed)) {
    throw new Error(`${relative(filePath)} must contain a JSON object`);
  }
  return parsed as T;
}

function configPath(...parts: string[]): string {
  return path.join(REPO_ROOT, "config", ...parts);
}

function isJsonObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function relative(filePath: string): string {
  return path.relative(REPO_ROOT, filePath);
}

import { ethers } from "ethers";
import { connectBridge } from "../clients/bridge";
import { assertConfiguredChain, createProvider } from "../clients/provider";
import { resolveBridgeAddress, resolveTokenAddress } from "../config/load";
import { OpsConfig } from "../config/types";
import { formatBool, printResolvedContext } from "../format";
import { parsePositiveInteger, parseNonce } from "../tx/parse";
import { CommandOptions, requireOption } from "./options";
import {
  printClaimable,
  printNativeBridge,
  printTokenBridge,
  resolveTokenDecimals,
  resolveTokenMetadata
} from "./bridgeShared";

export async function bridgeState(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const bridge = connectBridge(bridgeAddress, provider);
  printResolvedContext(config, { Bridge: bridgeAddress });

  const [management, bridgePaused, withdrawalsPaused, unclaimedRewards, nativeIsSet] = await Promise.all([
    bridge.management(),
    bridge.bridgePaused(),
    bridge.withdrawalsPaused(),
    bridge.unclaimedRewards(),
    bridge.nativeBridgeIsSet()
  ]);

  console.log("Bridge");
  console.log(`  Management:          ${management}`);
  console.log(`  Bridge paused:       ${formatBool(bridgePaused)}`);
  console.log(`  Withdrawals paused:  ${formatBool(withdrawalsPaused)}`);
  console.log(`  Unclaimed rewards:   ${ethers.formatEther(unclaimedRewards)} (${unclaimedRewards.toString()} raw)`);
  console.log("");

  console.log("Native bridge");
  console.log(`  Set:                 ${formatBool(nativeIsSet)}`);
  if (nativeIsSet) {
    const nativeBridge = await bridge.nativeBridge();
    printNativeBridge(nativeBridge);
  }

  console.log("");
  await printRegisteredTokens(config, bridge, provider, options);
}

export async function bridgeClaimable(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const nonce = parseNonce(requireOption(options, "nonce"));
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const bridge = connectBridge(bridgeAddress, provider);

  if (options.token) {
    const tokenAddress = resolveTokenAddress(config, options.token);
    printResolvedContext(config, { Bridge: bridgeAddress, Token: tokenAddress, Nonce: nonce.toString() });
    const isRegistered = await bridge.isRegisteredToken(tokenAddress);
    console.log(`Token registered: ${formatBool(isRegistered)}`);
    if (!isRegistered) return;

    const [tokenBridge, claimable] = await Promise.all([
      bridge.tokenBridges(tokenAddress),
      bridge.tokenClaimables(tokenAddress, nonce)
    ]);
    const decimals = await resolveTokenDecimals(provider, tokenAddress, config.deployment.tokens?.[options.token]?.decimals);
    printTokenBridge(tokenBridge, decimals);
    printClaimable(claimable, decimals, "token");
    return;
  }

  printResolvedContext(config, { Bridge: bridgeAddress, Nonce: nonce.toString() });
  const nativeIsSet = await bridge.nativeBridgeIsSet();
  console.log(`Native bridge set: ${formatBool(nativeIsSet)}`);
  if (!nativeIsSet) return;

  const [nativeBridge, claimable] = await Promise.all([
    bridge.nativeBridge(),
    bridge.claimableNative(nonce)
  ]);
  printNativeBridge(nativeBridge);
  printClaimable(claimable, 8, "native");
}

export async function bridgeToken(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const tokenInput = requireOption(options, "token");
  const tokenAddress = resolveTokenAddress(config, tokenInput);
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const bridge = connectBridge(bridgeAddress, provider);

  printResolvedContext(config, { Bridge: bridgeAddress, Token: tokenAddress });
  await printTokenState(config, bridge, provider, tokenAddress, tokenInput);
}

async function printRegisteredTokens(
  config: OpsConfig,
  bridge: ReturnType<typeof connectBridge>,
  provider: ethers.JsonRpcProvider,
  options: CommandOptions
): Promise<void> {
  const maxTokens = options["max-tokens"] ? parsePositiveInteger(options["max-tokens"], "max-tokens") : 100;

  console.log("Token bridges");
  const tokens = await discoverRegisteredTokens(bridge, maxTokens);
  if (tokens.length === 0) {
    console.log("  None registered");
    return;
  }
  if (tokens.length === maxTokens) {
    console.log(`  Reached --max-tokens ${maxTokens}; increase it if more registered tokens are expected.`);
  }

  for (let i = 0; i < tokens.length; i++) {
    const tokenAddress = tokens[i];
    console.log("");
    console.log(`  [${i}] ${tokenAddress}`);
    await printTokenState(config, bridge, provider, tokenAddress, tokenAddress, "    ");
  }
}

async function discoverRegisteredTokens(
  bridge: ReturnType<typeof connectBridge>,
  maxTokens: number
): Promise<string[]> {
  const tokens: string[] = [];
  for (let index = 0; index < maxTokens; index++) {
    try {
      tokens.push(ethers.getAddress(await bridge.registeredTokens(index)));
    } catch (error) {
      // registeredTokens(index) reverts when index is out of bounds; treat that as end-of-list.
      if (!ethers.isCallException(error)) throw error;
      break;
    }
  }
  return tokens;
}

async function printTokenState(
  config: OpsConfig,
  bridge: ReturnType<typeof connectBridge>,
  provider: ethers.Provider,
  tokenAddress: string,
  tokenInput: string,
  indent = ""
): Promise<void> {
  const isRegistered = await bridge.isRegisteredToken(tokenAddress);
  console.log(`${indent}Registered:          ${formatBool(isRegistered)}`);
  if (!isRegistered) return;

  const tokenBridge = await bridge.tokenBridges(tokenAddress);
  const configuredDecimals = config.deployment.tokens?.[tokenInput]?.decimals;
  const decimals = await resolveTokenDecimals(provider, tokenAddress, configuredDecimals);
  const metadata = await resolveTokenMetadata(provider, tokenAddress);
  if (metadata.symbol) console.log(`${indent}Symbol:              ${metadata.symbol}`);
  console.log(`${indent}Decimals:            ${decimals}`);
  console.log(`${indent}Neo N3 token:        ${tokenBridge.config.neoN3Token}`);
  printTokenBridge(tokenBridge, decimals, indent);
}

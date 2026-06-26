import { ethers } from "ethers";
import { connectBridge } from "../clients/bridge";
import { connectErc20Metadata } from "../clients/erc20";
import { assertConfiguredChain, createProvider } from "../clients/provider";
import { loadOpsConfig, resolveBridgeAddress, resolveTokenAddress } from "../config/load";
import { formatAmount, formatBool, isEmptyClaimable, printResolvedContext } from "../format";
import { CommandOptions, hasHelpArg, isHelpArg, parseOptions, requireOption } from "./options";

export async function runBridgeCommand(args: string[]): Promise<void> {
  const [command, ...rest] = args;
  if (!command || isHelpArg(command) || hasHelpArg(rest)) {
    printBridgeHelp();
    return;
  }
  const options = parseOptions(rest);
  const network = requireOption(options, "network");
  const config = loadOpsConfig(network);

  if (command === "state") {
    await bridgeState(config, options);
    return;
  }
  if (command === "claimable") {
    await bridgeClaimable(config, options);
    return;
  }
  if (command === "token") {
    await bridgeToken(config, options);
    return;
  }
  throw new Error(`Unknown bridge command: ${command ?? "(missing)"}`);
}

function printBridgeHelp(): void {
  console.log(`Bridge commands

Usage:
  npm run ops -- bridge state --network <network> [--bridge <address>] [--max-tokens <count>]
  npm run ops -- bridge token --network <network> --token <alias-or-address> [--bridge <address>]
  npm run ops -- bridge claimable --network <network> --nonce <nonce> [--token <alias-or-address>] [--bridge <address>]

Commands:
  state       Print native bridge state and registered token bridges.
  token       Print state for one token bridge.
  claimable   Check native or token claimable state for one nonce.

Options:
  --network      Required. One of local, neox-devnet, neox-testnet, neox-mainnet.
  --bridge       Optional bridge address override.
  --token        Token alias from deployment config or direct token address.
  --nonce        Claimable nonce.
  --max-tokens   Maximum registeredTokens(index) entries to read for state.
`);
}

async function bridgeState(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
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

async function bridgeClaimable(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
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

async function bridgeToken(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
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
  config: ReturnType<typeof loadOpsConfig>,
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
  config: ReturnType<typeof loadOpsConfig>,
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

function printNativeBridge(nativeBridge: Awaited<ReturnType<ReturnType<typeof connectBridge>["nativeBridge"]>>): void {
  console.log(`  Paused:              ${formatBool(nativeBridge.paused)}`);
  console.log(`  Deposit nonce:       ${nativeBridge.depositState.nonce.toString()}`);
  console.log(`  Deposit root:        ${nativeBridge.depositState.root}`);
  console.log(`  Withdrawal nonce:    ${nativeBridge.withdrawalState.nonce.toString()}`);
  console.log(`  Withdrawal root:     ${nativeBridge.withdrawalState.root}`);
  console.log(`  Fee:                 ${ethers.formatEther(nativeBridge.config.fee)} (${nativeBridge.config.fee.toString()} raw)`);
  console.log(`  Min amount:          ${ethers.formatEther(nativeBridge.config.minAmount)} (${nativeBridge.config.minAmount.toString()} raw)`);
  console.log(`  Max amount:          ${ethers.formatEther(nativeBridge.config.maxAmount)} (${nativeBridge.config.maxAmount.toString()} raw)`);
  console.log(`  Max deposits:        ${nativeBridge.config.maxDeposits.toString()}`);
  console.log(`  Decimal scaling:     ${nativeBridge.config.decimalScalingFactor.toString()}`);
}

function printTokenBridge(tokenBridge: Awaited<ReturnType<ReturnType<typeof connectBridge>["tokenBridges"]>>, decimals: number, indent = ""): void {
  console.log(`${indent}Token bridge`);
  console.log(`${indent}  Paused:            ${formatBool(tokenBridge.paused)}`);
  console.log(`${indent}  Deposit nonce:     ${tokenBridge.depositState.nonce.toString()}`);
  console.log(`${indent}  Deposit root:      ${tokenBridge.depositState.root}`);
  console.log(`${indent}  Withdrawal nonce:  ${tokenBridge.withdrawalState.nonce.toString()}`);
  console.log(`${indent}  Withdrawal root:   ${tokenBridge.withdrawalState.root}`);
  console.log(`${indent}  Fee:               ${ethers.formatEther(tokenBridge.config.fee)} (${tokenBridge.config.fee.toString()} raw)`);
  console.log(`${indent}  Min amount:        ${formatAmount(tokenBridge.config.minAmount, decimals)}`);
  console.log(`${indent}  Max amount:        ${formatAmount(tokenBridge.config.maxAmount, decimals)}`);
  console.log(`${indent}  Max deposits:      ${tokenBridge.config.maxDeposits.toString()}`);
  console.log(`${indent}  Decimal scaling:   ${tokenBridge.config.decimalScalingFactor.toString()}`);
}

function printClaimable(claimable: { to: string; amount: bigint }, decimals: number, label: string): void {
  console.log("");
  console.log("Claimable");
  if (isEmptyClaimable(claimable)) {
    console.log("  Found:               no");
    return;
  }
  console.log("  Found:               yes");
  console.log(`  Recipient:           ${claimable.to}`);
  console.log(`  Amount:              ${formatAmount(claimable.amount, decimals)} ${label}`);
}

async function resolveTokenDecimals(provider: ethers.Provider, tokenAddress: string, configured?: number): Promise<number> {
  if (configured !== undefined) return configured;
  try {
    return Number(await connectErc20Metadata(tokenAddress, provider).decimals());
  } catch {
    return 18;
  }
}

async function resolveTokenMetadata(provider: ethers.Provider, tokenAddress: string): Promise<{ symbol?: string }> {
  try {
    const token = connectErc20Metadata(tokenAddress, provider);
    return { symbol: await token.symbol() };
  } catch {
    return {};
  }
}

function parseNonce(value: string): bigint {
  if (!/^\d+$/.test(value)) throw new Error(`Invalid nonce: ${value}`);
  return BigInt(value);
}

function parsePositiveInteger(value: string, label: string): number {
  if (!/^\d+$/.test(value)) throw new Error(`Invalid ${label}: ${value}`);
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) throw new Error(`Invalid ${label}: ${value}`);
  return parsed;
}

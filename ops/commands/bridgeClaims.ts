import { connectBridge } from "../clients/bridge";
import { resolveBridgeAddress, resolveTokenAddress } from "../config/load";
import { OpsConfig } from "../config/types";
import { isEmptyClaimable, printResolvedContext, formatBool } from "../format";
import { createWriteContext } from "../tx/context";
import { parseNonce } from "../tx/parse";
import { parseDryRunFlag } from "../tx/send";
import { printTransactionSummary } from "../tx/summary";
import { parseYesFlag } from "../tx/guards";
import { CommandOptions, requireOption } from "./options";
import { finishBridgeTransaction, nativeClaimableDecimals, printClaimable, resolveTokenDecimals } from "./bridgeShared";

export async function bridgeClaimNative(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const nonce = parseNonce(requireOption(options, "nonce"));
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);

  printResolvedContext(config, { Bridge: bridgeAddress, Account: accountName, Sender: context.sender, Nonce: nonce.toString() });

  const nativeBridge = await assertNativeClaimOpen(config, bridge);

  const claimable = await bridge.claimableNative(nonce);
  printClaimable(claimable, nativeClaimableDecimals(nativeBridge), "native");
  if (isEmptyClaimable(claimable)) {
    throw new Error(`No native claimable found for nonce ${nonce.toString()}`);
  }

  const request = await bridge.claimNative.populateTransaction(nonce);
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "claimNative",
    args: {
      nonce,
      recipient: claimable.to,
      amountRaw: claimable.amount
    },
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

export async function bridgeClaimToken(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const tokenInput = requireOption(options, "token");
  const tokenAddress = resolveTokenAddress(config, tokenInput);
  const nonce = parseNonce(requireOption(options, "nonce"));
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);

  printResolvedContext(config, {
    Bridge: bridgeAddress,
    Account: accountName,
    Sender: context.sender,
    Token: tokenAddress,
    Nonce: nonce.toString()
  });

  const isRegistered = await bridge.isRegisteredToken(tokenAddress);
  console.log(`Token registered: ${formatBool(isRegistered)}`);
  if (!isRegistered) throw new Error(`Token ${tokenAddress} is not registered on ${config.networkName}`);

  await assertTokenClaimOpen(config, bridge, tokenAddress);

  const [claimable, decimals] = await Promise.all([
    bridge.tokenClaimables(tokenAddress, nonce),
    resolveTokenDecimals(context.provider, tokenAddress, config.deployment.tokens?.[tokenInput]?.decimals)
  ]);
  printClaimable(claimable, decimals, "token");
  if (isEmptyClaimable(claimable)) {
    throw new Error(`No token claimable found for token ${tokenAddress} and nonce ${nonce.toString()}`);
  }

  const request = await bridge.claimToken.populateTransaction(tokenAddress, nonce);
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "claimToken",
    args: {
      token: tokenAddress,
      nonce,
      recipient: claimable.to,
      amountRaw: claimable.amount
    },
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

async function assertNativeClaimOpen(
  config: OpsConfig,
  bridge: ReturnType<typeof connectBridge>
): Promise<Awaited<ReturnType<ReturnType<typeof connectBridge>["nativeBridge"]>>> {
  const [bridgePaused, nativeIsSet] = await Promise.all([
    bridge.bridgePaused(),
    bridge.nativeBridgeIsSet()
  ]);

  if (bridgePaused) {
    throw new Error(`Bridge is paused on ${config.networkName}; cannot claim native funds.`);
  }
  if (!nativeIsSet) {
    throw new Error(`Native bridge is not configured on ${config.networkName}; cannot claim native funds.`);
  }

  const nativeBridge = await bridge.nativeBridge();
  if (nativeBridge.paused) {
    throw new Error(`Native bridge is paused on ${config.networkName}; cannot claim native funds.`);
  }
  return nativeBridge;
}

async function assertTokenClaimOpen(
  config: OpsConfig,
  bridge: ReturnType<typeof connectBridge>,
  tokenAddress: string
): Promise<void> {
  const bridgePaused = await bridge.bridgePaused();
  if (bridgePaused) {
    throw new Error(`Bridge is paused on ${config.networkName}; cannot claim token funds.`);
  }

  const tokenBridge = await bridge.tokenBridges(tokenAddress);
  if (tokenBridge.paused) {
    throw new Error(`Token bridge ${tokenAddress} is paused on ${config.networkName}; cannot claim token funds.`);
  }
}

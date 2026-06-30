import { ethers } from "ethers";
import { connectBridge } from "../clients/bridge";
import { resolveBridgeAddress, resolveTokenAddress } from "../config/load";
import { OpsConfig } from "../config/types";
import { formatBool, printResolvedContext } from "../format";
import { createWriteContext, WriteContext } from "../tx/context";
import { parseYesFlag } from "../tx/guards";
import { parseDryRunFlag } from "../tx/send";
import { printTransactionSummary } from "../tx/summary";
import { CommandOptions, requireOption } from "./options";
import { finishBridgeTransaction } from "./bridgeShared";

type ControlAction = "pause" | "unpause";
type ControlTarget = "bridge" | "withdrawals" | "native" | "token";

interface ControlOperation {
  target: ControlTarget;
  label: string;
  readPaused: () => Promise<boolean>;
  pauseAction: string;
  unpauseAction: string;
  populatePause: () => Promise<ethers.TransactionRequest>;
  populateUnpause: () => Promise<ethers.TransactionRequest>;
}

const TARGETS = ["bridge", "withdrawals", "native", "token", "all"] as const;

export async function bridgeControl(config: OpsConfig, options: CommandOptions, action: ControlAction): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const target = parseTarget(requireOption(options, "target"));
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const tokenAddress = options.token ? resolveTokenAddress(config, options.token) : undefined;
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);

  printResolvedContext(config, {
    Bridge: bridgeAddress,
    Account: accountName,
    Sender: context.sender,
    Target: target,
    Token: tokenAddress
  });

  const operations = await createOperations(config, bridge, target, tokenAddress);
  for (const operation of operations) {
    await runControlOperation(config, context, bridgeAddress, operation, action, dryRun, confirmed);
  }
}

async function createOperations(
  config: OpsConfig,
  bridge: ReturnType<typeof connectBridge>,
  target: ControlTarget | "all",
  tokenAddress: string | undefined
): Promise<ControlOperation[]> {
  const operations: ControlOperation[] = [
    {
      target: "bridge",
      label: "Bridge",
      readPaused: () => bridge.bridgePaused(),
      pauseAction: "pauseBridge",
      unpauseAction: "unpauseBridge",
      populatePause: () => bridge.pauseBridge.populateTransaction(),
      populateUnpause: () => bridge.unpauseBridge.populateTransaction()
    },
    {
      target: "withdrawals",
      label: "Withdrawals",
      readPaused: () => bridge.withdrawalsPaused(),
      pauseAction: "pauseWithdrawals",
      unpauseAction: "unpauseWithdrawals",
      populatePause: () => bridge.pauseWithdrawals.populateTransaction(),
      populateUnpause: () => bridge.unpauseWithdrawals.populateTransaction()
    }
  ];

  const nativeBridgeIsSet = await bridge.nativeBridgeIsSet();
  if (nativeBridgeIsSet) {
    operations.push({
      target: "native",
      label: "Native bridge",
      readPaused: async () => (await bridge.nativeBridge()).paused,
      pauseAction: "pauseNativeBridge",
      unpauseAction: "unpauseNativeBridge",
      populatePause: () => bridge.pauseNativeBridge.populateTransaction(),
      populateUnpause: () => bridge.unpauseNativeBridge.populateTransaction()
    });
  } else if (target === "native") {
    throw new Error(`Native bridge is not configured on ${config.networkName}.`);
  }

  if (target === "token" && !tokenAddress) {
    throw new Error("Missing required option --token");
  }

  if (tokenAddress) {
    const isRegistered = await bridge.isRegisteredToken(tokenAddress);
    if (!isRegistered) throw new Error(`Token ${tokenAddress} is not registered on ${config.networkName}.`);
    operations.push({
      target: "token",
      label: "Token bridge",
      readPaused: async () => (await bridge.tokenBridges(tokenAddress)).paused,
      pauseAction: "pauseTokenBridge",
      unpauseAction: "unpauseTokenBridge",
      populatePause: () => bridge.pauseTokenBridge.populateTransaction(tokenAddress),
      populateUnpause: () => bridge.unpauseTokenBridge.populateTransaction(tokenAddress)
    });
  }

  if (target === "all") return operations;
  return operations.filter((operation) => operation.target === target);
}

async function runControlOperation(
  config: OpsConfig,
  context: WriteContext,
  bridgeAddress: string,
  operation: ControlOperation,
  action: ControlAction,
  dryRun: boolean,
  confirmed: boolean
): Promise<void> {
  const paused = await operation.readPaused();
  const desiredPaused = action === "pause";

  console.log(operation.label);
  console.log(`  Currently paused: ${formatBool(paused)}`);

  if (paused === desiredPaused) {
    console.log(`  Action:           already ${action}d; no transaction needed`);
    console.log("");
    return;
  }

  const request = action === "pause" ? await operation.populatePause() : await operation.populateUnpause();
  const contractAction = action === "pause" ? operation.pauseAction : operation.unpauseAction;
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: contractAction,
    args: {
      target: operation.target
    },
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

function parseTarget(value: string): ControlTarget | "all" {
  if ((TARGETS as readonly string[]).includes(value)) return value as ControlTarget | "all";
  throw new Error(`Invalid target: ${value}. Expected bridge, withdrawals, native, token, or all.`);
}

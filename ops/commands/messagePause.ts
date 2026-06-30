import { ethers } from "ethers";
import { connectMessageBridge } from "../clients/messageBridge";
import { resolveMessageBridgeAddress } from "../config/load";
import { OpsConfig } from "../config/types";
import { formatBool, printResolvedContext } from "../format";
import { createWriteContext, WriteContext } from "../tx/context";
import { parseYesFlag, requireMainnetConfirmation } from "../tx/guards";
import { printTransactionReceipt } from "../tx/receipt";
import { parseDryRunFlag, runTransactionRequest } from "../tx/send";
import { printTransactionSummary } from "../tx/summary";
import { CommandOptions, requireOption } from "./options";

type PauseAction = "pause" | "unpause";
type PauseTarget = "bridge" | "sending" | "executing";

interface PauseOperation {
  target: PauseTarget;
  label: string;
  readPaused: () => Promise<boolean>;
  pauseAction: string;
  unpauseAction: string;
  populatePause: () => Promise<ethers.TransactionRequest>;
  populateUnpause: () => Promise<ethers.TransactionRequest>;
}

const TARGETS = ["bridge", "sending", "executing", "all"] as const;

export async function messagePause(config: OpsConfig, options: CommandOptions, action: PauseAction): Promise<void> {
  const messageBridgeAddress = resolveMessageBridgeAddress(config, options["message-bridge"]);
  const accountName = requireOption(options, "account");
  const target = parseTarget(requireOption(options, "target"));
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const messageBridge = connectMessageBridge(messageBridgeAddress, context.wallet);

  printResolvedContext(config, {
    MessageBridge: messageBridgeAddress,
    Account: accountName,
    Sender: context.sender,
    Target: target
  });

  const operations = createOperations(messageBridge).filter((operation) => target === "all" || operation.target === target);
  for (const operation of operations) {
    await runPauseOperation(config, context, messageBridgeAddress, operation, action, dryRun, confirmed);
  }
}

function createOperations(messageBridge: ReturnType<typeof connectMessageBridge>): PauseOperation[] {
  return [
    {
      target: "bridge",
      label: "Message bridge",
      readPaused: () => messageBridge.messageBridgePaused(),
      pauseAction: "pause",
      unpauseAction: "unpause",
      populatePause: () => messageBridge.pause.populateTransaction(),
      populateUnpause: () => messageBridge.unpause.populateTransaction()
    },
    {
      target: "sending",
      label: "Message sending",
      readPaused: () => messageBridge.sendingPaused(),
      pauseAction: "pauseSending",
      unpauseAction: "unpauseSending",
      populatePause: () => messageBridge.pauseSending.populateTransaction(),
      populateUnpause: () => messageBridge.unpauseSending.populateTransaction()
    },
    {
      target: "executing",
      label: "Message executing",
      readPaused: () => messageBridge.executingPaused(),
      pauseAction: "pauseExecuting",
      unpauseAction: "unpauseExecuting",
      populatePause: () => messageBridge.pauseExecuting.populateTransaction(),
      populateUnpause: () => messageBridge.unpauseExecuting.populateTransaction()
    }
  ];
}

async function runPauseOperation(
  config: OpsConfig,
  context: WriteContext,
  messageBridgeAddress: string,
  operation: PauseOperation,
  action: PauseAction,
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
    contract: messageBridgeAddress,
    action: contractAction,
    args: {
      target: operation.target
    },
    request,
    dryRun
  });
  await finishTransaction(config, context, request, dryRun, confirmed);
}

async function finishTransaction(
  config: OpsConfig,
  context: WriteContext,
  request: ethers.TransactionRequest,
  dryRun: boolean,
  confirmed: boolean
): Promise<void> {
  if (!dryRun) requireMainnetConfirmation(config, confirmed);

  const result = await runTransactionRequest(context, request, { dryRun });
  if (!result.sent) {
    console.log("Dry run complete. Transaction was not sent.");
    return;
  }
  printTransactionReceipt(result.receipt);
}

function parseTarget(value: string): PauseTarget | "all" {
  if ((TARGETS as readonly string[]).includes(value)) return value as PauseTarget | "all";
  throw new Error(`Invalid target: ${value}. Expected bridge, sending, executing, or all.`);
}

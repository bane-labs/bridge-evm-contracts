import { ethers } from "ethers";
import { connectMessageBridge } from "../clients/messageBridge";
import { resolveMessageBridgeAddress } from "../config/load";
import { OpsConfig } from "../config/types";
import { formatBool, printResolvedContext } from "../format";
import { createWriteContext, WriteContext } from "../tx/context";
import { parseYesFlag, requireMainnetConfirmation } from "../tx/guards";
import { parsePositiveAmount } from "../tx/parse";
import { printTransactionReceipt } from "../tx/receipt";
import { parseDryRunFlag, runTransactionRequest } from "../tx/send";
import { printTransactionSummary } from "../tx/summary";
import { CommandOptions, requireOption } from "./options";

export async function messageSetSendingFee(config: OpsConfig, options: CommandOptions): Promise<void> {
  const messageBridgeAddress = resolveMessageBridgeAddress(config, options["message-bridge"]);
  const accountName = requireOption(options, "account");
  const amount = parsePositiveAmount(requireOption(options, "amount"), 18, "amount");
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const messageBridge = connectMessageBridge(messageBridgeAddress, context.wallet);

  printResolvedContext(config, {
    MessageBridge: messageBridgeAddress,
    Account: accountName,
    Sender: context.sender
  });

  const currentSendingFee = await messageBridge.sendingFee();
  console.log("Sending fee");
  console.log(`  Current:           ${ethers.formatEther(currentSendingFee)} (${currentSendingFee.toString()} wei)`);
  console.log(`  Requested:         ${ethers.formatEther(amount)} (${amount.toString()} wei)`);
  console.log(`  Already set:       ${formatBool(currentSendingFee === amount)}`);
  console.log("");

  if (currentSendingFee === amount) {
    console.log("Sending fee already set to requested value. No transaction needed.");
    return;
  }

  const request = await messageBridge.setSendingFee.populateTransaction(amount);
  printTransactionSummary(context, {
    contract: messageBridgeAddress,
    action: "setSendingFee",
    args: {
      amountRaw: amount
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

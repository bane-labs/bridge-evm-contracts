import { ethers } from "ethers";
import { connectErc20Metadata } from "../clients/erc20";
import { resolveBridgeAddress, resolveTokenAddress } from "../config/load";
import { OpsConfig } from "../config/types";
import { formatAmount, printResolvedContext } from "../format";
import { createWriteContext, WriteContext } from "../tx/context";
import { parseYesFlag } from "../tx/guards";
import { parsePositiveAmount } from "../tx/parse";
import { parseDryRunFlag } from "../tx/send";
import { printTransactionSummary } from "../tx/summary";
import { CommandOptions, requireOption } from "./options";
import { finishBridgeTransaction, resolveTokenDecimals } from "./bridgeShared";

export async function bridgeFundNative(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const amount = parsePositiveAmount(requireOption(options, "amount"), 18, "amount");
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);

  printResolvedContext(config, { Bridge: bridgeAddress, Account: accountName, Sender: context.sender });
  await assertNativeBalance(context, amount);

  const request: ethers.TransactionRequest = {
    to: bridgeAddress,
    value: amount
  };
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "fundNative",
    args: {
      amountRaw: amount
    },
    value: amount,
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

export async function bridgeFundToken(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const tokenInput = requireOption(options, "token");
  const tokenAddress = resolveTokenAddress(config, tokenInput);
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const token = connectErc20Metadata(tokenAddress, context.wallet);
  const decimals = await resolveTokenDecimals(context.provider, tokenAddress, config.deployment.tokens?.[tokenInput]?.decimals);
  const amount = parsePositiveAmount(requireOption(options, "amount"), decimals, "amount");

  printResolvedContext(config, {
    Bridge: bridgeAddress,
    Account: accountName,
    Sender: context.sender,
    Token: tokenAddress
  });

  const balance = await token.balanceOf(context.sender);
  console.log("Token funding");
  console.log(`  Amount:              ${formatAmount(amount, decimals)}`);
  console.log(`  Sender balance:      ${formatAmount(balance, decimals)}`);
  console.log("");
  if (balance < amount) {
    throw new Error(`Insufficient token balance: need ${formatAmount(amount, decimals)}, have ${formatAmount(balance, decimals)}.`);
  }

  const request = await token.transfer.populateTransaction(bridgeAddress, amount);
  printTransactionSummary(context, {
    contract: tokenAddress,
    action: "transfer",
    args: {
      to: bridgeAddress,
      amountRaw: amount
    },
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

async function assertNativeBalance(context: WriteContext, amount: bigint): Promise<void> {
  const balance = await context.provider.getBalance(context.sender);
  console.log("Native funding");
  console.log(`  Amount:              ${ethers.formatEther(amount)} (${amount.toString()} wei)`);
  console.log(`  Sender balance:      ${ethers.formatEther(balance)} (${balance.toString()} wei)`);
  console.log("");
  if (balance < amount) {
    throw new Error(`Insufficient native balance: need ${ethers.formatEther(amount)}, have ${ethers.formatEther(balance)}.`);
  }
}

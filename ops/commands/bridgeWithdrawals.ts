import { ethers } from "ethers";
import { connectBridge } from "../clients/bridge";
import { connectErc20Metadata } from "../clients/erc20";
import { resolveBridgeAddress, resolveTokenAddress } from "../config/load";
import { OpsConfig } from "../config/types";
import { formatAmount, printResolvedContext } from "../format";
import { createWriteContext, WriteContext } from "../tx/context";
import { parseAddress, parsePositiveAmount } from "../tx/parse";
import { parseDryRunFlag } from "../tx/send";
import { printTransactionSummary } from "../tx/summary";
import { parseYesFlag } from "../tx/guards";
import { CommandOptions, requireOption } from "./options";
import { finishBridgeTransaction, resolveTokenDecimals } from "./bridgeShared";

export async function bridgeWithdrawNative(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const recipient = parseRecipientAddress(requireOption(options, "to"));
  const amount = parsePositiveAmount(requireOption(options, "amount"), 18, "amount");
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);

  printResolvedContext(config, {
    Bridge: bridgeAddress,
    Account: accountName,
    Sender: context.sender,
    Recipient: recipient
  });

  const nativeBridge = await assertNativeWithdrawalOpen(config, bridge);
  assertWithdrawalAmount("Native withdrawal amount", amount, nativeBridge.config, 18);
  const totalValue = amount + nativeBridge.config.fee;
  await assertNativeBalance(context, totalValue, "native withdrawal amount plus fee");

  console.log("Native withdrawal");
  console.log(`  Amount:              ${formatAmount(amount, 18)} native`);
  console.log(`  Fee:                 ${ethers.formatEther(nativeBridge.config.fee)} (${nativeBridge.config.fee.toString()} wei)`);
  console.log(`  Total value:         ${ethers.formatEther(totalValue)} (${totalValue.toString()} wei)`);
  console.log("");

  const request = await bridge.withdrawNative.populateTransaction(recipient, nativeBridge.config.fee, { value: totalValue });
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "withdrawNative",
    args: {
      recipient,
      amountRaw: amount,
      maxFeeRaw: nativeBridge.config.fee
    },
    value: totalValue,
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

export async function bridgeWithdrawToken(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const tokenInput = requireOption(options, "token");
  const tokenAddress = resolveTokenAddress(config, tokenInput);
  const recipient = parseRecipientAddress(requireOption(options, "to"));
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const approve = parsePresenceFlag(options.approve);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);
  const token = connectErc20Metadata(tokenAddress, context.wallet);
  const decimals = await resolveTokenDecimals(context.provider, tokenAddress, config.deployment.tokens?.[tokenInput]?.decimals);
  const amount = parsePositiveAmount(requireOption(options, "amount"), decimals, "amount");

  printResolvedContext(config, {
    Bridge: bridgeAddress,
    Account: accountName,
    Sender: context.sender,
    Token: tokenAddress,
    Recipient: recipient
  });

  const tokenBridge = await assertTokenWithdrawalOpen(config, bridge, tokenAddress);
  assertWithdrawalAmount("Token withdrawal amount", amount, tokenBridge.config, decimals);
  await assertNativeBalance(context, tokenBridge.config.fee, "token withdrawal fee");

  const [tokenBalance, allowance] = await Promise.all([
    token.balanceOf(context.sender),
    token.allowance(context.sender, bridgeAddress)
  ]);

  console.log("Token withdrawal");
  console.log(`  Amount:              ${formatAmount(amount, decimals)}`);
  console.log(`  Fee:                 ${ethers.formatEther(tokenBridge.config.fee)} (${tokenBridge.config.fee.toString()} wei)`);
  console.log(`  Token balance:       ${formatAmount(tokenBalance, decimals)}`);
  console.log(`  Current allowance:   ${formatAmount(allowance, decimals)}`);
  console.log("");

  if (tokenBalance < amount) {
    throw new Error(`Insufficient token balance: need ${formatAmount(amount, decimals)}, have ${formatAmount(tokenBalance, decimals)}.`);
  }

  if (allowance < amount) {
    if (!approve) {
      throw new Error(`Token allowance is too low. Rerun with --approve to approve ${formatAmount(amount, decimals)} for ${bridgeAddress}.`);
    }

    const approveRequest = await token.approve.populateTransaction(bridgeAddress, amount);
    printTransactionSummary(context, {
      contract: tokenAddress,
      action: "approve",
      args: {
        spender: bridgeAddress,
        amountRaw: amount
      },
      request: approveRequest,
      dryRun
    });
    await finishBridgeTransaction(config, context, approveRequest, dryRun, confirmed);
  }

  const request = await bridge.withdrawToken.populateTransaction(tokenAddress, recipient, amount, { value: tokenBridge.config.fee });
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "withdrawToken",
    args: {
      token: tokenAddress,
      recipient,
      amountRaw: amount
    },
    value: tokenBridge.config.fee,
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

async function assertNativeWithdrawalOpen(
  config: OpsConfig,
  bridge: ReturnType<typeof connectBridge>
): Promise<Awaited<ReturnType<ReturnType<typeof connectBridge>["nativeBridge"]>>> {
  const [bridgePaused, withdrawalsPaused, nativeIsSet] = await Promise.all([
    bridge.bridgePaused(),
    bridge.withdrawalsPaused(),
    bridge.nativeBridgeIsSet()
  ]);

  if (bridgePaused) {
    throw new Error(`Bridge is paused on ${config.networkName}; cannot withdraw native funds.`);
  }
  if (withdrawalsPaused) {
    throw new Error(`Withdrawals are paused on ${config.networkName}; cannot withdraw native funds.`);
  }
  if (!nativeIsSet) {
    throw new Error(`Native bridge is not configured on ${config.networkName}; cannot withdraw native funds.`);
  }

  const nativeBridge = await bridge.nativeBridge();
  if (nativeBridge.paused) {
    throw new Error(`Native bridge is paused on ${config.networkName}; cannot withdraw native funds.`);
  }
  return nativeBridge;
}

async function assertTokenWithdrawalOpen(
  config: OpsConfig,
  bridge: ReturnType<typeof connectBridge>,
  tokenAddress: string
): Promise<Awaited<ReturnType<ReturnType<typeof connectBridge>["tokenBridges"]>>> {
  const [bridgePaused, withdrawalsPaused, isRegistered] = await Promise.all([
    bridge.bridgePaused(),
    bridge.withdrawalsPaused(),
    bridge.isRegisteredToken(tokenAddress)
  ]);

  if (bridgePaused) {
    throw new Error(`Bridge is paused on ${config.networkName}; cannot withdraw token funds.`);
  }
  if (withdrawalsPaused) {
    throw new Error(`Withdrawals are paused on ${config.networkName}; cannot withdraw token funds.`);
  }
  if (!isRegistered) {
    throw new Error(`Token ${tokenAddress} is not registered on ${config.networkName}.`);
  }

  const tokenBridge = await bridge.tokenBridges(tokenAddress);
  if (tokenBridge.paused) {
    throw new Error(`Token bridge ${tokenAddress} is paused on ${config.networkName}; cannot withdraw token funds.`);
  }
  return tokenBridge;
}

function assertWithdrawalAmount(
  label: string,
  amount: bigint,
  config: { minAmount: bigint; maxAmount: bigint; decimalScalingFactor: bigint },
  decimals: number
): void {
  const scalingFactor = 10n ** config.decimalScalingFactor;
  if (amount % scalingFactor !== 0n) {
    throw new Error(`${label} must be divisible by ${scalingFactor.toString()} raw units.`);
  }
  if (amount < config.minAmount) {
    throw new Error(`${label} is below minimum: ${formatAmount(amount, decimals)} < ${formatAmount(config.minAmount, decimals)}.`);
  }
  if (amount > config.maxAmount) {
    throw new Error(`${label} exceeds maximum: ${formatAmount(amount, decimals)} > ${formatAmount(config.maxAmount, decimals)}.`);
  }
}

async function assertNativeBalance(context: WriteContext, required: bigint, label: string): Promise<void> {
  const balance = await context.provider.getBalance(context.sender);
  console.log(`Sender native balance: ${ethers.formatEther(balance)} (${balance.toString()} wei)`);
  if (balance < required) {
    throw new Error(`Insufficient native balance for ${label}: need ${ethers.formatEther(required)}, have ${ethers.formatEther(balance)}.`);
  }
}

function parsePresenceFlag(value: string | undefined): boolean {
  return value !== undefined;
}

function parseRecipientAddress(value: string): string {
  const recipient = parseAddress(value, "to");
  if (recipient === ethers.ZeroAddress) throw new Error("Invalid to: zero address");
  return recipient;
}

import { ethers } from "ethers";
import { connectBridge } from "../clients/bridge";
import { resolveBridgeAddress, resolveTokenAddress } from "../config/load";
import { OpsConfig } from "../config/types";
import { formatAmount, formatBool, printResolvedContext } from "../format";
import { createWriteContext, WriteContext } from "../tx/context";
import { parseYesFlag } from "../tx/guards";
import { parseAmount, parseNonNegativeInteger, parsePositiveAmount, parsePositiveInteger } from "../tx/parse";
import { parseDryRunFlag } from "../tx/send";
import { printTransactionSummary } from "../tx/summary";
import { CommandOptions, requireOption } from "./options";
import { finishBridgeTransaction, resolveTokenDecimals } from "./bridgeShared";

type NativeBridge = Awaited<ReturnType<ReturnType<typeof connectBridge>["nativeBridge"]>>;
type TokenBridge = Awaited<ReturnType<ReturnType<typeof connectBridge>["tokenBridges"]>>;

export async function bridgeConfigureNative(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const fee = parsePositiveAmount(requireOption(options, "fee"), 18, "fee");
  const minAmount = parseAmount(requireOption(options, "min"), 18, "min");
  const maxAmount = parsePositiveAmount(requireOption(options, "max"), 18, "max");
  const maxDeposits = parsePositiveInteger(requireOption(options, "max-deposits"), "max-deposits");
  const decimalsHere = parseBridgeDecimals(requireOption(options, "decimals-here"), "decimals-here");
  const decimalsOnN3 = parseBridgeDecimals(requireOption(options, "decimals-n3"), "decimals-n3");
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);

  printResolvedContext(config, { Bridge: bridgeAddress, Account: accountName, Sender: context.sender });

  const nativeBridgeIsSet = await bridge.nativeBridgeIsSet();
  console.log("Native bridge configuration");
  console.log(`  Already configured: ${formatBool(nativeBridgeIsSet)}`);
  console.log(`  Fee:                ${ethers.formatEther(fee)} (${fee.toString()} wei)`);
  console.log(`  Min amount:         ${ethers.formatEther(minAmount)} (${minAmount.toString()} wei)`);
  console.log(`  Max amount:         ${ethers.formatEther(maxAmount)} (${maxAmount.toString()} wei)`);
  console.log(`  Max deposits:       ${maxDeposits.toString()}`);
  console.log(`  Decimals here:      ${decimalsHere.toString()}`);
  console.log(`  Decimals on N3:     ${decimalsOnN3.toString()}`);
  console.log("");

  if (nativeBridgeIsSet) {
    throw new Error("Native bridge is already configured. Use the individual set-native-* commands for updates.");
  }
  if (minAmount >= maxAmount) {
    throw new Error("Native min amount must be lower than max amount.");
  }

  const request = await bridge.setNativeBridge.populateTransaction(
    fee,
    minAmount,
    maxAmount,
    maxDeposits,
    decimalsHere,
    decimalsOnN3
  );
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "setNativeBridge",
    args: {
      feeRaw: fee,
      minAmountRaw: minAmount,
      maxAmountRaw: maxAmount,
      maxDeposits,
      decimalsHere,
      decimalsOnN3
    },
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

export async function bridgeSetNativeFee(config: OpsConfig, options: CommandOptions): Promise<void> {
  await setNativeAmount(config, options, {
    action: "setNativeWithdrawalFee",
    label: "Native withdrawal fee",
    option: "amount",
    parse: (value) => parsePositiveAmount(value, 18, "amount"),
    current: (nativeBridge) => nativeBridge.config.fee,
    validate: (amount, nativeBridge) => assertNativeScaledAmount("Native withdrawal fee", amount, nativeBridge),
    populate: (bridge, amount) => bridge.setNativeWithdrawalFee.populateTransaction(amount)
  });
}

export async function bridgeSetNativeMin(config: OpsConfig, options: CommandOptions): Promise<void> {
  await setNativeAmount(config, options, {
    action: "setMinNativeWithdrawalAmount",
    label: "Min native withdrawal amount",
    option: "amount",
    parse: (value) => parseAmount(value, 18, "amount"),
    current: (nativeBridge) => nativeBridge.config.minAmount,
    validate: (amount, nativeBridge) => {
      assertNativeScaledAmount("Min native withdrawal amount", amount, nativeBridge);
      if (amount >= nativeBridge.config.maxAmount) {
        throw new Error(`Min native withdrawal amount must be lower than current max (${ethers.formatEther(nativeBridge.config.maxAmount)}).`);
      }
    },
    populate: (bridge, amount) => bridge.setMinNativeWithdrawalAmount.populateTransaction(amount)
  });
}

export async function bridgeSetNativeMax(config: OpsConfig, options: CommandOptions): Promise<void> {
  await setNativeAmount(config, options, {
    action: "setMaxNativeWithdrawalAmount",
    label: "Max native withdrawal amount",
    option: "amount",
    parse: (value) => parsePositiveAmount(value, 18, "amount"),
    current: (nativeBridge) => nativeBridge.config.maxAmount,
    validate: (amount, nativeBridge) => {
      assertNativeScaledAmount("Max native withdrawal amount", amount, nativeBridge);
      if (amount <= nativeBridge.config.minAmount) {
        throw new Error(`Max native withdrawal amount must be greater than current min (${ethers.formatEther(nativeBridge.config.minAmount)}).`);
      }
    },
    populate: (bridge, amount) => bridge.setMaxNativeWithdrawalAmount.populateTransaction(amount)
  });
}

export async function bridgeSetNativeMaxDeposits(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const maxDeposits = parsePositiveInteger(requireOption(options, "max-deposits"), "max-deposits");
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);
  const nativeBridge = await requireNativeBridge(config, bridge);

  printResolvedContext(config, { Bridge: bridgeAddress, Account: accountName, Sender: context.sender });
  printConfigChange("Max native deposits", nativeBridge.config.maxDeposits, BigInt(maxDeposits), (value) => value.toString());
  if (nativeBridge.config.maxDeposits === BigInt(maxDeposits)) return printAlreadySet("Max native deposits");

  const request = await bridge.setMaxNativeDeposits.populateTransaction(maxDeposits);
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "setMaxNativeDeposits",
    args: { maxDeposits },
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

export async function bridgeSetTokenFee(config: OpsConfig, options: CommandOptions): Promise<void> {
  await setTokenAmount(config, options, {
    action: "setTokenWithdrawalFee",
    label: "Token withdrawal fee",
    parse: (value) => parsePositiveAmount(value, 18, "amount"),
    current: (tokenBridge) => tokenBridge.config.fee,
    format: (value) => `${ethers.formatEther(value)} (${value.toString()} wei)`,
    validate: () => undefined,
    populate: (bridge, tokenAddress, amount) => bridge.setTokenWithdrawalFee.populateTransaction([tokenAddress], [amount])
  });
}

export async function bridgeSetTokenMin(config: OpsConfig, options: CommandOptions): Promise<void> {
  await setTokenAmount(config, options, {
    action: "setMinTokenWithdrawalAmount",
    label: "Min token withdrawal amount",
    parse: (value, decimals) => parseAmount(value, decimals, "amount"),
    current: (tokenBridge) => tokenBridge.config.minAmount,
    format: (value, decimals) => formatAmount(value, decimals),
    validate: (amount, tokenBridge, decimals) => {
      if (amount >= tokenBridge.config.maxAmount) {
        throw new Error(`Min token withdrawal amount must be lower than current max (${formatAmount(tokenBridge.config.maxAmount, decimals)}).`);
      }
    },
    populate: (bridge, tokenAddress, amount) => bridge.setMinTokenWithdrawalAmount.populateTransaction([tokenAddress], [amount])
  });
}

export async function bridgeSetTokenMax(config: OpsConfig, options: CommandOptions): Promise<void> {
  await setTokenAmount(config, options, {
    action: "setMaxTokenWithdrawalAmount",
    label: "Max token withdrawal amount",
    parse: (value, decimals) => parsePositiveAmount(value, decimals, "amount"),
    current: (tokenBridge) => tokenBridge.config.maxAmount,
    format: (value, decimals) => formatAmount(value, decimals),
    validate: (amount, tokenBridge, decimals) => {
      if (amount <= tokenBridge.config.minAmount) {
        throw new Error(`Max token withdrawal amount must be greater than current min (${formatAmount(tokenBridge.config.minAmount, decimals)}).`);
      }
    },
    populate: (bridge, tokenAddress, amount) => bridge.setMaxTokenWithdrawalAmount.populateTransaction([tokenAddress], [amount])
  });
}

export async function bridgeSetTokenMaxDeposits(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const tokenInput = requireOption(options, "token");
  const tokenAddress = resolveTokenAddress(config, tokenInput);
  const maxDeposits = parsePositiveInteger(requireOption(options, "max-deposits"), "max-deposits");
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);
  const tokenBridge = await requireTokenBridge(config, bridge, tokenAddress);

  printResolvedContext(config, { Bridge: bridgeAddress, Account: accountName, Sender: context.sender, Token: tokenAddress });
  printConfigChange("Max token deposits", tokenBridge.config.maxDeposits, BigInt(maxDeposits), (value) => value.toString());
  if (tokenBridge.config.maxDeposits === BigInt(maxDeposits)) return printAlreadySet("Max token deposits");

  const request = await bridge.setMaxTokenDeposits.populateTransaction([tokenAddress], [maxDeposits]);
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "setMaxTokenDeposits",
    args: { token: tokenAddress, maxDeposits },
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

async function setNativeAmount(
  config: OpsConfig,
  options: CommandOptions,
  setter: {
    action: string;
    label: string;
    option: string;
    parse: (value: string) => bigint;
    current: (nativeBridge: NativeBridge) => bigint;
    validate: (amount: bigint, nativeBridge: NativeBridge) => void;
    populate: (bridge: ReturnType<typeof connectBridge>, amount: bigint) => Promise<ethers.TransactionRequest>;
  }
): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const amount = setter.parse(requireOption(options, setter.option));
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);
  const nativeBridge = await requireNativeBridge(config, bridge);
  setter.validate(amount, nativeBridge);

  printResolvedContext(config, { Bridge: bridgeAddress, Account: accountName, Sender: context.sender });
  const current = setter.current(nativeBridge);
  printConfigChange(setter.label, current, amount, (value) => `${ethers.formatEther(value)} (${value.toString()} wei)`);
  if (current === amount) return printAlreadySet(setter.label);

  const request = await setter.populate(bridge, amount);
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: setter.action,
    args: { amountRaw: amount },
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

async function setTokenAmount(
  config: OpsConfig,
  options: CommandOptions,
  setter: {
    action: string;
    label: string;
    parse: (value: string, decimals: number) => bigint;
    current: (tokenBridge: TokenBridge) => bigint;
    format: (value: bigint, decimals: number) => string;
    validate: (amount: bigint, tokenBridge: TokenBridge, decimals: number) => void;
    populate: (bridge: ReturnType<typeof connectBridge>, tokenAddress: string, amount: bigint) => Promise<ethers.TransactionRequest>;
  }
): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const tokenInput = requireOption(options, "token");
  const tokenAddress = resolveTokenAddress(config, tokenInput);
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);
  const [tokenBridge, decimals] = await Promise.all([
    requireTokenBridge(config, bridge, tokenAddress),
    resolveTokenDecimals(context.provider, tokenAddress, config.deployment.tokens?.[tokenInput]?.decimals)
  ]);
  const amount = setter.parse(requireOption(options, "amount"), decimals);
  setter.validate(amount, tokenBridge, decimals);

  printResolvedContext(config, { Bridge: bridgeAddress, Account: accountName, Sender: context.sender, Token: tokenAddress });
  const current = setter.current(tokenBridge);
  printConfigChange(setter.label, current, amount, (value) => setter.format(value, decimals));
  if (current === amount) return printAlreadySet(setter.label);

  const request = await setter.populate(bridge, tokenAddress, amount);
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: setter.action,
    args: { token: tokenAddress, amountRaw: amount },
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

async function requireNativeBridge(
  config: OpsConfig,
  bridge: ReturnType<typeof connectBridge>
): Promise<NativeBridge> {
  const nativeBridgeIsSet = await bridge.nativeBridgeIsSet();
  if (!nativeBridgeIsSet) throw new Error(`Native bridge is not configured on ${config.networkName}.`);
  return bridge.nativeBridge();
}

async function requireTokenBridge(
  config: OpsConfig,
  bridge: ReturnType<typeof connectBridge>,
  tokenAddress: string
): Promise<TokenBridge> {
  const isRegistered = await bridge.isRegisteredToken(tokenAddress);
  if (!isRegistered) throw new Error(`Token ${tokenAddress} is not registered on ${config.networkName}.`);
  return bridge.tokenBridges(tokenAddress);
}

function assertNativeScaledAmount(label: string, amount: bigint, nativeBridge: NativeBridge): void {
  const scalingDivisor = 10n ** nativeBridge.config.decimalScalingFactor;
  if (amount % scalingDivisor !== 0n) {
    throw new Error(`${label} must be divisible by ${scalingDivisor.toString()} wei.`);
  }
}

function parseBridgeDecimals(value: string, label: string): number {
  const parsed = parseNonNegativeInteger(value, label);
  if (parsed > 36) throw new Error(`Invalid ${label}: ${value}`);
  return parsed;
}

function printConfigChange(label: string, current: bigint, requested: bigint, format: (value: bigint) => string): void {
  console.log(label);
  console.log(`  Current:   ${format(current)}`);
  console.log(`  Requested: ${format(requested)}`);
  console.log(`  Changed:   ${formatBool(current !== requested)}`);
  console.log("");
}

function printAlreadySet(label: string): void {
  console.log(`${label} already set to requested value. No transaction needed.`);
}

import { ethers } from "ethers";
import { connectBridge } from "../clients/bridge";
import { resolveBridgeAddress, resolveTokenAddress } from "../config/load";
import { OpsConfig } from "../config/types";
import { formatAmount, formatBool, printResolvedContext } from "../format";
import { createWriteContext } from "../tx/context";
import { parseYesFlag } from "../tx/guards";
import { parseAddress, parseNonNegativeInteger, parsePositiveAmount, parsePositiveInteger } from "../tx/parse";
import { parseDryRunFlag } from "../tx/send";
import { printTransactionSummary } from "../tx/summary";
import { CommandOptions, requireOption } from "./options";
import { finishBridgeTransaction, resolveTokenDecimals } from "./bridgeShared";

export async function bridgeRegisterToken(config: OpsConfig, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const tokenInput = requireOption(options, "token");
  const tokenAddress = resolveTokenAddress(config, tokenInput);
  const neoN3Token = parseNonZeroAddress(resolveNeoN3Token(config, tokenInput, options["neo-n3-token"]), "neo-n3-token");
  const fee = parsePositiveAmount(requireOption(options, "fee"), 18, "fee");
  const maxDeposits = parsePositiveInteger(requireOption(options, "max-deposits"), "max-deposits");
  const decimalScalingFactor = parseScalingFactor(options["scaling-factor"] ?? "0");
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);
  const decimals = await resolveTokenDecimals(context.provider, tokenAddress, config.deployment.tokens?.[tokenInput]?.decimals);
  const minAmount = parsePositiveAmount(requireOption(options, "min"), decimals, "min");
  const maxAmount = parsePositiveAmount(requireOption(options, "max"), decimals, "max");

  if (minAmount >= maxAmount) throw new Error("Token min amount must be lower than max amount.");

  printResolvedContext(config, {
    Bridge: bridgeAddress,
    Account: accountName,
    Sender: context.sender,
    Token: tokenAddress
  });

  const isRegistered = await bridge.isRegisteredToken(tokenAddress);
  console.log("Token registration");
  console.log(`  Registered:         ${formatBool(isRegistered)}`);
  console.log(`  Neo N3 token:       ${neoN3Token}`);
  console.log(`  Fee:                ${ethers.formatEther(fee)} (${fee.toString()} wei)`);
  console.log(`  Min amount:         ${formatAmount(minAmount, decimals)}`);
  console.log(`  Max amount:         ${formatAmount(maxAmount, decimals)}`);
  console.log(`  Max deposits:       ${maxDeposits.toString()}`);
  console.log(`  Decimal scaling:    ${decimalScalingFactor.toString()}`);
  console.log("");

  if (isRegistered) throw new Error(`Token ${tokenAddress} is already registered on ${config.networkName}.`);

  const tokenConfig = {
    neoN3Token,
    fee,
    minAmount,
    maxAmount,
    maxDeposits,
    decimalScalingFactor
  };
  const request = await bridge.registerToken.populateTransaction(tokenAddress, tokenConfig);
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "registerToken",
    args: {
      token: tokenAddress,
      neoN3Token,
      feeRaw: fee,
      minAmountRaw: minAmount,
      maxAmountRaw: maxAmount,
      maxDeposits,
      decimalScalingFactor
    },
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

function resolveNeoN3Token(config: OpsConfig, tokenInput: string, explicit?: string): string {
  if (explicit) return explicit;
  const configured = config.deployment.tokens?.[tokenInput]?.neoN3;
  if (configured) return configured;
  throw new Error("Missing required option --neo-n3-token");
}

function parseNonZeroAddress(value: string, label: string): string {
  const address = parseAddress(value, label);
  if (address === ethers.ZeroAddress) throw new Error(`Invalid ${label}: zero address`);
  return address;
}

function parseScalingFactor(value: string): number {
  const parsed = parseNonNegativeInteger(value, "scaling-factor");
  if (parsed > 36) throw new Error(`Invalid scaling-factor: ${value}`);
  return parsed;
}

import { ethers } from "ethers";
import { connectBridge } from "../clients/bridge";
import { connectErc20Metadata } from "../clients/erc20";
import { OpsConfig } from "../config/types";
import { formatAmount, formatBool, isEmptyClaimable } from "../format";
import { WriteContext } from "../tx/context";
import { printTransactionReceipt } from "../tx/receipt";
import { runTransactionRequest } from "../tx/send";
import { requireMainnetConfirmation } from "../tx/guards";

export async function finishBridgeTransaction(
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

export function printNativeBridge(nativeBridge: Awaited<ReturnType<ReturnType<typeof connectBridge>["nativeBridge"]>>): void {
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

export function printTokenBridge(tokenBridge: Awaited<ReturnType<ReturnType<typeof connectBridge>["tokenBridges"]>>, decimals: number, indent = ""): void {
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

export function printClaimable(claimable: { to: string; amount: bigint }, decimals: number, label: string): void {
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

export function nativeClaimableDecimals(nativeBridge: Awaited<ReturnType<ReturnType<typeof connectBridge>["nativeBridge"]>>): number {
  const decimalScalingFactor = Number(nativeBridge.config.decimalScalingFactor);
  if (!Number.isSafeInteger(decimalScalingFactor) || decimalScalingFactor < 0 || decimalScalingFactor > 18) {
    throw new Error(`Unsupported native bridge decimal scaling factor: ${nativeBridge.config.decimalScalingFactor.toString()}`);
  }
  return 18 - decimalScalingFactor;
}

export async function resolveTokenDecimals(provider: ethers.Provider, tokenAddress: string, configured?: number): Promise<number> {
  if (configured !== undefined) return configured;
  try {
    return Number(await connectErc20Metadata(tokenAddress, provider).decimals());
  } catch {
    return 18;
  }
}

export async function resolveTokenMetadata(provider: ethers.Provider, tokenAddress: string): Promise<{ symbol?: string }> {
  try {
    const token = connectErc20Metadata(tokenAddress, provider);
    return { symbol: await token.symbol() };
  } catch {
    return {};
  }
}

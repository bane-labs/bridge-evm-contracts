import { ethers } from "ethers";
import { WriteContext } from "./context";

export interface TransactionSummary {
  contract: string;
  action: string;
  args?: Record<string, string | number | bigint | boolean | undefined>;
  value?: bigint;
  request: ethers.TransactionRequest;
  dryRun: boolean;
}

export function printTransactionSummary(context: WriteContext, summary: TransactionSummary): void {
  console.log("Transaction summary");
  console.log(`  Network:    ${context.config.networkName}`);
  console.log(`  Account:    ${context.accountName}`);
  console.log(`  Sender:     ${context.sender}`);
  console.log(`  Contract:   ${summary.contract}`);
  console.log(`  Action:     ${summary.action}`);
  console.log(`  Dry run:    ${summary.dryRun ? "yes" : "no"}`);
  console.log(`  Value:      ${formatWei(summary.value ?? valueFromRequest(summary.request))}`);

  const args = Object.entries(summary.args ?? {}).filter(([, value]) => value !== undefined);
  if (args.length > 0) {
    console.log("  Arguments:");
    for (const [name, value] of args) {
      console.log(`    ${name}: ${formatValue(value)}`);
    }
  }

  printRequestGas(summary.request);
  console.log("");
}

function printRequestGas(request: ethers.TransactionRequest): void {
  const rows: Array<[string, ethers.BigNumberish | null | undefined, "units" | "gwei"]> = [
    ["Gas limit", request.gasLimit, "units"],
    ["Gas price", request.gasPrice, "gwei"],
    ["Max fee per gas", request.maxFeePerGas, "gwei"],
    ["Max priority fee", request.maxPriorityFeePerGas, "gwei"]
  ];
  const visibleRows = rows.filter(([, value]) => value !== undefined && value !== null);
  if (visibleRows.length === 0) return;

  console.log("  Gas:");
  for (const [label, value, kind] of visibleRows) {
    console.log(`    ${label}: ${kind === "units" ? formatGasLimit(value) : formatGasPrice(value)}`);
  }
}

function valueFromRequest(request: ethers.TransactionRequest): bigint | undefined {
  if (request.value === undefined || request.value === null) return undefined;
  return ethers.getBigInt(request.value);
}

function formatWei(value: bigint | undefined): string {
  const amount = value ?? 0n;
  return `${ethers.formatEther(amount)} (${amount.toString()} wei)`;
}

function formatGasLimit(value: ethers.BigNumberish | null | undefined): string {
  if (value === undefined || value === null) return "";
  return ethers.getBigInt(value).toString();
}

function formatGasPrice(value: ethers.BigNumberish | null | undefined): string {
  if (value === undefined || value === null) return "";
  const parsed = ethers.getBigInt(value);
  return `${ethers.formatUnits(parsed, "gwei")} gwei (${parsed.toString()} wei)`;
}

function formatValue(value: string | number | bigint | boolean | undefined): string {
  if (typeof value === "bigint") return value.toString();
  return String(value);
}

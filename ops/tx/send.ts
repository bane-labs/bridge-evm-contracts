import { ethers } from "ethers";
import { WriteContext } from "./context";

export interface TransactionRunOptions {
  dryRun: boolean;
  confirmations?: number;
}

export type TransactionRunResult =
  | {
      sent: false;
      request: ethers.TransactionRequest;
    }
  | {
      sent: true;
      response: ethers.TransactionResponse;
      receipt: ethers.TransactionReceipt;
    };

export function parseDryRunFlag(value: string | undefined): boolean {
  if (value === undefined) return false;
  if (value === "true" || value === "yes" || value === "1") return true;
  if (value === "false" || value === "no" || value === "0") return false;
  throw new Error(`Invalid --dry-run value: ${value}`);
}

export async function runTransactionRequest(
  context: WriteContext,
  request: ethers.TransactionRequest,
  options: TransactionRunOptions
): Promise<TransactionRunResult> {
  const requestWithSender = { ...request, from: context.sender };
  if (options.dryRun) return { sent: false, request: requestWithSender };

  const response = await context.wallet.sendTransaction(requestWithSender);
  const receipt = await response.wait(options.confirmations ?? 1);
  if (!receipt) throw new Error(`Transaction ${response.hash} was not mined before the wait timed out`);

  return { sent: true, response, receipt };
}

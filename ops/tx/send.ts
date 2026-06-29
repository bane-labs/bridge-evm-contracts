import { ethers } from "ethers";
import { WriteContext } from "./context";
import { parseBooleanOption } from "./parse";

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
  return parseBooleanOption(value, "--dry-run");
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

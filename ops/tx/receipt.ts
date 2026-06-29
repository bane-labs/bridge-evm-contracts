import { ethers } from "ethers";

export function printTransactionReceipt(receipt: ethers.TransactionReceipt): void {
  console.log("Transaction receipt");
  console.log(`  Hash:         ${receipt.hash}`);
  console.log(`  Status:       ${formatStatus(receipt.status)}`);
  console.log(`  Block:        ${receipt.blockNumber}`);
  console.log(`  From:         ${receipt.from}`);
  if (receipt.to) console.log(`  To:           ${receipt.to}`);
  if (receipt.contractAddress) console.log(`  Contract:     ${receipt.contractAddress}`);
  console.log(`  Gas used:     ${receipt.gasUsed.toString()}`);
  console.log(`  Gas price:    ${ethers.formatUnits(receipt.gasPrice, "gwei")} gwei (${receipt.gasPrice.toString()} wei)`);
  console.log(`  Fee paid:     ${ethers.formatEther(receipt.fee)} (${receipt.fee.toString()} wei)`);
  console.log(`  Logs:         ${receipt.logs.length}`);
  console.log("");
}

function formatStatus(status: number | null): string {
  if (status === 1) return "success";
  if (status === 0) return "failed";
  return "unknown";
}

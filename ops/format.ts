import { ethers } from "ethers";
import { OpsConfig } from "./config/types";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export function printResolvedContext(config: OpsConfig, extra: Record<string, string | undefined> = {}): void {
  const rows: Array<[string, string | number | undefined]> = [
    ["Network", config.networkName],
    ["Chain ID", config.network.chainId],
    ["RPC URL", config.network.rpcUrl],
    ["Network config", config.sources.network],
    ["Network override", config.sources.networkOverride],
    ["Deployment", config.sources.deployment],
    ["Deployment override", config.sources.deploymentOverride],
    ...Object.entries(extra)
  ];
  const visibleRows = rows.filter(([, value]) => value !== undefined && value !== "");
  const labelWidth = Math.max(...visibleRows.map(([label]) => label.length));

  console.log("Resolved context");
  for (const [label, value] of visibleRows) {
    console.log(`  ${`${label}:`.padEnd(labelWidth + 1)} ${value}`);
  }
  console.log("");
}

export function formatBool(value: boolean): string {
  return value ? "yes" : "no";
}

export function formatAmount(value: bigint, decimals: number): string {
  return `${ethers.formatUnits(value, decimals)} (${value.toString()} raw)`;
}

export function isEmptyClaimable(claimable: { to: string; amount: bigint }): boolean {
  return claimable.amount === 0n || claimable.to.toLowerCase() === ZERO_ADDRESS;
}

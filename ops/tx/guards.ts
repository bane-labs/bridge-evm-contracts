import { OpsConfig } from "../config/types";

export function isMainnet(config: OpsConfig): boolean {
  return config.networkName === "neox-mainnet";
}

export function requireMainnetConfirmation(config: OpsConfig, confirmed: boolean): void {
  if (!isMainnet(config) || confirmed) return;

  throw new Error("Refusing to send a mainnet transaction without --yes. Review the transaction summary, then rerun with --yes if intended.");
}

export function parseYesFlag(value: string | undefined): boolean {
  if (value === undefined) return false;
  if (value === "true" || value === "yes" || value === "1") return true;
  throw new Error(`Invalid --yes value: ${value}`);
}

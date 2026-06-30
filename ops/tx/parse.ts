import { ethers } from "ethers";

export function parseNonce(value: string, label = "nonce"): bigint {
  if (!/^\d+$/.test(value)) throw new Error(`Invalid ${label}: ${value}`);
  return BigInt(value);
}

export function parseAddress(value: string, label = "address"): string {
  if (!ethers.isAddress(value)) throw new Error(`Invalid ${label}: ${value}`);
  return ethers.getAddress(value);
}

export function parsePositiveInteger(value: string, label: string): number {
  if (!/^\d+$/.test(value)) throw new Error(`Invalid ${label}: ${value}`);
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) throw new Error(`Invalid ${label}: ${value}`);
  return parsed;
}

export function parseNonNegativeInteger(value: string, label: string): number {
  if (!/^\d+$/.test(value)) throw new Error(`Invalid ${label}: ${value}`);
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) throw new Error(`Invalid ${label}: ${value}`);
  return parsed;
}

export function parseAmount(value: string, decimals: number, label = "amount"): bigint {
  try {
    return ethers.parseUnits(value, decimals);
  } catch {
    throw new Error(`Invalid ${label}: ${value}`);
  }
}

export function parsePositiveAmount(value: string, decimals: number, label = "amount"): bigint {
  const parsed = parseAmount(value, decimals, label);
  if (parsed <= 0n) throw new Error(`Invalid ${label}: ${value}`);
  return parsed;
}

export function parseBooleanOption(value: string | undefined, label: string): boolean {
  if (value === undefined) return false;
  if (value === "true" || value === "yes" || value === "1") return true;
  if (value === "false" || value === "no" || value === "0") return false;
  throw new Error(`Invalid ${label} value: ${value}`);
}

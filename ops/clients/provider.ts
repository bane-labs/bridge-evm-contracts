import { ethers } from "ethers";
import { NetworkConfig } from "../config/types";

export function createProvider(network: NetworkConfig): ethers.JsonRpcProvider {
  return new ethers.JsonRpcProvider(network.rpcUrl, network.chainId);
}

export async function assertConfiguredChain(provider: ethers.Provider, expectedChainId: number): Promise<void> {
  const actual = await provider.getNetwork();
  if (actual.chainId !== BigInt(expectedChainId)) {
    throw new Error(`RPC chain id mismatch: expected ${expectedChainId}, got ${actual.chainId.toString()}`);
  }
}

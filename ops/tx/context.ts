import { ethers } from "ethers";
import { loadAccountWallet } from "../accounts/load";
import { assertConfiguredChain, createProvider } from "../clients/provider";
import { OpsConfig } from "../config/types";

export interface WriteContext {
  config: OpsConfig;
  provider: ethers.JsonRpcProvider;
  accountName: string;
  wallet: ethers.BaseWallet;
  sender: string;
}

export async function createWriteContext(config: OpsConfig, accountName: string): Promise<WriteContext> {
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const wallet = await loadAccountWallet(config, accountName, provider);

  return {
    config,
    provider,
    accountName,
    wallet,
    sender: wallet.address
  };
}

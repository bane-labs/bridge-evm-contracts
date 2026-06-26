export interface NetworkConfig {
  name: string;
  hardhatNetwork?: string;
  chainId: number;
  rpcUrl: string;
  gas?: {
    gasPriceGwei?: string;
    maxFeePerGasGwei?: string;
    maxPriorityFeePerGasGwei?: string;
  };
}

export interface DeploymentConfig {
  network: string;
  contracts: {
    bridge?: string;
    bridgeManagement?: string;
    messageBridge?: string;
    executionManager?: string;
  };
  tokens?: Record<string, TokenConfig>;
}

export interface TokenConfig {
  neoX?: string;
  neoN3?: string;
  decimals?: number;
  symbol?: string;
}

export type AccountSource =
  | {
      type: "keystore";
      path: string;
      passwordEnv?: string;
    }
  | {
      type: "privateKeyEnv";
      env: string;
    };

export interface AccountConfig {
  network: string;
  accounts: Record<string, AccountSource>;
}

export interface OpsConfig {
  networkName: string;
  network: NetworkConfig;
  deployment: DeploymentConfig;
  accounts: AccountConfig;
  sources: {
    network: string;
    deployment?: string;
    deploymentOverride?: string;
    accounts?: string;
  };
}

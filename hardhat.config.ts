import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-solhint";
import '@typechain/hardhat'
import '@openzeppelin/hardhat-upgrades'
import '@nomicfoundation/hardhat-chai-matchers'
import 'hardhat-storage-layout'

const NEOX_DEVNET_ACCOUNTS = vars.has("NEOX_DEVNET_PRIVATE_KEY") ? [vars.get("NEOX_DEVNET_PRIVATE_KEY")] : [];
const NEOX_TESTNET_ACCOUNTS = vars.has("NEOX_TESTNET_PRIVATE_KEY") ? [vars.get("NEOX_TESTNET_PRIVATE_KEY")] : [];
const NEOX_MAINNET_ACCOUNTS = vars.has("NEOX_MAINNET_PRIVATE_KEY") ? [vars.get("NEOX_MAINNET_PRIVATE_KEY")] : [];

const NEOX_DEVNET_RPC_URL = vars.has("NEOX_DEVNET_RPC_URL") ? vars.get("NEOX_DEVNET_RPC_URL") : "http://localhost:8562";
const NEOX_DEVNET_CHAIN_ID = vars.has("NEOX_DEVNET_CHAIN_ID") ? parseInt(vars.get("NEOX_DEVNET_CHAIN_ID")) : 2312251829;
const NEOX_DEVNET_GAS_PRICE = vars.has("NEOX_DEVNET_GAS_PRICE") ? parseInt(vars.get("NEOX_DEVNET_GAS_PRICE")) : 4000000000;

/** @type import('hardhat/config').HardhatUserConfig */
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.25",
    settings: {
      evmVersion: "shanghai",
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    hardhat: {
      // See its defaults
    },
    neoxTestnet: {
      url: "https://testnet.rpc.banelabs.org",
      chainId: 12227332,
      accounts: NEOX_TESTNET_ACCOUNTS,
      gasPrice: 4000000000,
    },
    neoxMainnet: {
      url: "https://mainnet-1.rpc.banelabs.org",
      chainId: 47763,
      accounts: NEOX_MAINNET_ACCOUNTS,
      gasPrice: 4000000000,
    },
    neoxDevnet: {
      url: NEOX_DEVNET_RPC_URL,
      chainId: NEOX_DEVNET_CHAIN_ID,
      accounts: NEOX_DEVNET_ACCOUNTS,
      gasPrice: NEOX_DEVNET_GAS_PRICE,
    },
  },
};

export default config;

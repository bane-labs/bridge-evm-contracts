import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-solhint";
import '@typechain/hardhat'
import '@openzeppelin/hardhat-upgrades'
import '@nomicfoundation/hardhat-chai-matchers'
import 'hardhat-storage-layout'
import "@nomicfoundation/hardhat-foundry";

const NEOX_TESTNET_ACCOUNTS = vars.has("NEOX_TESTNET_PRIVATE_KEY") ? [vars.get("NEOX_TESTNET_PRIVATE_KEY")] : [];

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
    neoxTestnet: {
      url: "https://testnet.rpc.banelabs.org",
      chainId: 12227332,
      accounts: NEOX_TESTNET_ACCOUNTS,
    },
  },
};

export default config;

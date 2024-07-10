import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-solhint";
import '@typechain/hardhat'
import '@openzeppelin/hardhat-upgrades'
import '@nomicfoundation/hardhat-chai-matchers'
import 'hardhat-storage-layout'
import "@nomicfoundation/hardhat-foundry";


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
};

export default config;

import { ethers } from "ethers";
import {
  IERC20Metadata,
  IERC20Metadata__factory,
  NeoToken,
  NeoToken__factory
} from "../../typechain-types";

export function connectErc20Metadata(address: string, runner: ethers.ContractRunner): IERC20Metadata {
  return IERC20Metadata__factory.connect(address, runner);
}

export function connectNeoToken(address: string, runner: ethers.ContractRunner): NeoToken {
  return NeoToken__factory.connect(address, runner);
}

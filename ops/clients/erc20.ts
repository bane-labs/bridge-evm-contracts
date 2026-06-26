import { ethers } from "ethers";
import { IERC20Metadata, IERC20Metadata__factory } from "../../typechain-types";

export function connectErc20Metadata(address: string, runner: ethers.ContractRunner): IERC20Metadata {
  return IERC20Metadata__factory.connect(address, runner);
}

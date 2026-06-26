import { ethers } from "ethers";
import { BridgeImpl, BridgeImpl__factory } from "../../typechain-types";

export function connectBridge(address: string, runner: ethers.ContractRunner): BridgeImpl {
  return BridgeImpl__factory.connect(address, runner);
}

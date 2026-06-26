import { ethers } from "ethers";
import { MessageBridge, MessageBridge__factory } from "../../typechain-types";

export function connectMessageBridge(address: string, runner: ethers.ContractRunner): MessageBridge {
  return MessageBridge__factory.connect(address, runner);
}

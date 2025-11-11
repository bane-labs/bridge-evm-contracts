import {ethers} from 'hardhat';
import {getGovernor} from '../utils/wallet';
import {fundIfLocalNetwork} from '../utils/network';
import { messageBridge } from '../../typechain-types/contracts';
import { Provider, Wallet } from 'ethers';

export async function getGovernorFundedIfLocal(provider: Provider): Promise<Wallet> {
  // Get governor account
  const governor = getGovernor(provider);
  const governorAddress = await governor.getAddress();
  console.log(`Governor Address: ${governorAddress}`);

  // Fund governor if on local network
  await fundIfLocalNetwork([governorAddress]);
  return governor;
}

export async function getMessageBridge(): Promise<messageBridge.MessageBridge> {
  const messageBridgeAddress = process.env.MESSAGE_BRIDGE_ADDRESS;

  if (!messageBridgeAddress) {
    console.error('Please set MESSAGE_BRIDGE_ADDRESS environment variable');
    process.exit(1);
  }

  if (!ethers.isAddress(messageBridgeAddress)) {
    console.error('MESSAGE_BRIDGE_ADDRESS must be a valid Ethereum address');
    process.exit(1);
  }

  return await ethers.getContractAt('MessageBridge', messageBridgeAddress);
}

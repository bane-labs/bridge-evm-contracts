import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { fundIfLocalNetwork } from "./network";
import { DEFAULT_TX_OVERRIDES } from "./constants";

/**
 * Message types supported by the MessageBridge
 */
export enum MessageType {
  EXECUTABLE = 0,
  STORE_ONLY = 1,
  RESULT = 2
}

/**
 * Options for sending messages to the MessageBridge
 */
export interface MessageOptions {
  /** The raw message data to send */
  message: string;
  /** The type of message (executable or store-only) */
  type: MessageType.EXECUTABLE | MessageType.STORE_ONLY;
  /** Whether to store the result (only applicable for executable messages) */
  storeResult?: boolean;
  /** Custom fee amount (if not provided, will use contract's sendingFee) */
  feeAmount?: bigint;
  /** Whether to fund the sender if on local network */
  autoFund?: boolean;
}

/**
 * Result of sending a message
 */
export interface SendMessageResult {
  /** Transaction hash */
  txHash: string;
  /** Message nonce */
  nonce: bigint;
  /** Transaction receipt */
  receipt: TransactionReceipt;
}

/**
 * Utility class for interacting with MessageBridge contracts
 */
export class MessageBridgeUtils {
  private messageBridge: MessageBridge;
  private signer: Signer;

  private constructor(messageBridge: MessageBridge, signer: Signer) {
    this.messageBridge = messageBridge;
    this.signer = signer;
  }

  /**
   * Create a new MessageBridgeUtils instance
   */
  static async create(messageBridgeAddress: string, signer: Signer): Promise<MessageBridgeUtils> {
    const messageBridge = await ethers.getContractAt("MessageBridge", messageBridgeAddress, signer);
    return new MessageBridgeUtils(messageBridge, signer);
  }

  /**
   * Send a message to the MessageBridge
   */
  async sendMessage(options: MessageOptions): Promise<SendMessageResult> {
    const {
      message,
      type,
      storeResult = true,
      feeAmount,
      autoFund = true
    } = options;

    // Auto-fund if on local network
    if (autoFund) {
      const signerAddress = await this.signer.getAddress();
      await fundIfLocalNetwork([signerAddress]);
    }

    // Get fee amount
    const fee = feeAmount ?? await this.messageBridge.sendingFee();

    console.log(`Sending ${type === MessageType.EXECUTABLE ? 'executable' : 'store-only'} message...`);
    console.log(`Message: ${message}`);
    console.log(`Fee: ${ethers.formatEther(fee)} ETH`);

    let tx;
    let receipt;

    try {
      if (type === MessageType.EXECUTABLE) {
        console.log(`Store result: ${storeResult}`);
        tx = await this.messageBridge.sendExecutableMessage(
          message,
          storeResult,
          { value: fee, ...DEFAULT_TX_OVERRIDES }
        );
      } else if (type === MessageType.STORE_ONLY) {
        tx = await this.messageBridge.sendStoreOnlyMessage(
          message,
          { value: fee, ...DEFAULT_TX_OVERRIDES }
        );
      } else {
        throw new Error(`Unsupported message type: ${type}`);
      }

      console.log(`Transaction sent: ${tx.hash}`);
      receipt = await tx.wait();
      console.log(`Transaction confirmed in block: ${receipt.blockNumber}`);

      // Extract nonce from MessageSend event
      let parsedLog: any;
      const messageSendEvent = receipt.logs.find((log: any) => {
        try {
          parsedLog = this.messageBridge.interface.parseLog(log);
          return parsedLog?.name === 'MessageSend';
        } catch {
          return false;
        }
      });

      let nonce: bigint;
      if (messageSendEvent) {
        nonce = parsedLog?.args.nonce;
        console.log(`Message sent with nonce: ${nonce}`);
      } else {
        throw new Error("Could not find MessageSend event in transaction receipt");
      }

      return {
        txHash: tx.hash,
        nonce,
        receipt
      };

    } catch (error) {
      console.error("Error sending message:", error);
      throw error;
    }
  }

  /**
   * Get the execution state of an executable message
   */
  async getExecutableState(nonce: bigint) {
    try {
      const state: ExecutableStateStructOutput = await this.messageBridge.getExecutableState(nonce);
      console.log(`Executable state for nonce ${nonce}:`);
      console.log(`  Executed: ${state.executed}`);
      return state;
    } catch (error) {
      console.error(`Error getting executable state for nonce ${nonce}:`, error);
      throw error;
    }
  }

  /**
   * Get a stored message by nonce
   */
  async getMessage(nonce: bigint) {
    try {
      const message = await this.messageBridge.getEvmMessage(nonce);
      console.log(`Message for nonce ${nonce}:`);
      console.log(`  Raw message: ${message.rawMessage}`);
      console.log(`  Encoded metadata: ${message.encodedMetadata}`);
      return message;
    } catch (error) {
      console.error(`Error getting message for nonce ${nonce}:`, error);
      throw error;
    }
  }

  /**
   * Get the execution result of a message
   */
  async getResult(relatedMessageNonce: bigint) {
    try {
      const result = await this.messageBridge.getResult(relatedMessageNonce);
      console.log(`Result for message nonce ${relatedMessageNonce}:`);
      console.log(`  Success: ${result.success}`);
      console.log(`  Return data: ${result.returnData}`);
      return result;
    } catch (error) {
      console.error(`Error getting result for nonce ${relatedMessageNonce}:`, error);
      throw error;
    }
  }

  /**
   * Get the current sending fee
   */
  async getSendingFee(): Promise<bigint> {
    const fee = await this.messageBridge.sendingFee();
    console.log(`Current sending fee: ${ethers.formatEther(fee)} ETH`);
    return fee;
  }
}

/**
 * Create a MessageBridgeUtils instance
 */
export async function createMessageBridgeUtils(messageBridgeAddress: string, signer: Signer): Promise<MessageBridgeUtils> {
  return await MessageBridgeUtils.create(messageBridgeAddress, signer);
}

/**
 * Helper function to encode an EVM call for executable messages
 */
export function encodeEvmCall(target: string, callData: string, value: bigint = 0n, allowFailure: boolean = false): string {
  const abiCoder = new ethers.AbiCoder();
  const callStructAbi = ["tuple(address target, bool allowFailure, uint256 value, bytes callData)"];

  const evmCall = {
    target,
    allowFailure,
    value,
    callData
  };

  return abiCoder.encode(callStructAbi, [evmCall]);
}

/**
 * Helper function to encode a simple string message for store-only messages
 */
export function encodeStringMessage(message: string): string {
  return ethers.hexlify(ethers.toUtf8Bytes(message));
}

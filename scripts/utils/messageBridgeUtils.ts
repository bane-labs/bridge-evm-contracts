import { ethers } from "hardhat";
import { Signer, TransactionReceipt } from 'ethers';
import { fundIfLocalNetwork } from "./network";
import { DEFAULT_TX_OVERRIDES } from "./constants";
import { AMBStorage, MessageBridge, MessageBridge__factory } from '../../typechain-types';
import { getMessageBridgeFromEnv } from "./addresses";

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
export class MessageBridgeWrapper {
    private messageBridge: MessageBridge;
    private signer: Signer;

    private constructor(messageBridge: MessageBridge, signer: Signer) {
        this.messageBridge = messageBridge.connect(signer) as MessageBridge;
        this.signer = signer;
    }

    /**
     * Create a new MessageBridgeUtils instance
     */
    static async createFromAddress(messageBridgeAddress: string, signer: Signer): Promise<MessageBridgeWrapper> {
        const messageBridge = await ethers.getContractAt("MessageBridge", messageBridgeAddress, signer);
        return new MessageBridgeWrapper(messageBridge, signer);
    }

    /**
     *  Create a message bridge utils instance from a MessageBridge contract instance
     *
     */
    static async createFromHHVars(signer: Signer): Promise<MessageBridgeWrapper> {
        return new MessageBridgeWrapper(await getMessageBridgeFromEnv(), signer);
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

        // Validate message type in case of wrong cast of options.type
        if (type !== MessageType.EXECUTABLE && type !== MessageType.STORE_ONLY) {
            throw new Error(`Unsupported message type: ${type}`);
        }

        let tx;
        let receipt;

        if (type === MessageType.EXECUTABLE) {
            console.log(`Store result: ${storeResult}`);
            tx = await this.messageBridge.sendExecutableMessage(
                message,
                storeResult,
                {value: fee, ...DEFAULT_TX_OVERRIDES}
            );
        } else {
            // type === MessageType.STORE_ONLY
            tx = await this.messageBridge.sendStoreOnlyMessage(
                message,
                {value: fee, ...DEFAULT_TX_OVERRIDES}
            );
        }

        console.log(`Transaction sent: ${tx.hash}`);
        receipt = await tx.wait();

        if (!receipt) {
            throw new Error("Transaction receipt not available");
        }

        console.log(`Transaction confirmed in block: ${receipt.blockNumber}`);

        // Extract nonce from MessageSend event
        let nonce: bigint | undefined;

        for (const log of receipt.logs) {
            try {
                const parsedLog = this.messageBridge.interface.parseLog(log);
                if (parsedLog?.name === 'MessageSend') {
                    nonce = parsedLog.args.nonce;
                    console.log(`Message sent with nonce: ${nonce}`);
                    break;
                }
            } catch {
                // Skip logs that can't be parsed
            }
        }

        if (nonce === undefined) {
            throw new Error("Could not find MessageSend event in transaction receipt");
        }

        return {
            txHash: tx.hash,
            nonce,
            receipt
        };
    }

    /**
     * Get the execution state of an executable message
     */
    async getExecutableState(nonce: bigint) {
        const state: AMBStorage.ExecutableStateStructOutput = await this.messageBridge.getExecutableState(nonce);
        const expirationDate = new Date(Number(state.expirationTimestamp) * 1000);
        console.log(`Executable state for nonce ${nonce} - Executed: ${state.executed}, Expiration: ${expirationDate}`);
        return state;
    }

    /**
     * Execute a message by nonce
     */
    async executeMessage(nonce: bigint): Promise<void> {
        const signerAddress = await this.signer.getAddress();
        await fundIfLocalNetwork([signerAddress]);

        console.log(`Executing message with nonce: ${nonce}`);

        const tx = await this.messageBridge.executeMessage(nonce, DEFAULT_TX_OVERRIDES);
        console.log("Transaction sent. Hash:", tx.hash);

        const receipt = await tx.wait();
        if (receipt) {
            console.log('Transaction mined. Status:', receipt.status);
        } else {
            throw new Error("Transaction receipt is null");
        }
    }

    /**
     * Send a result message for a given nonce
     */
    async sendResultMessage(nonce: bigint): Promise<void> {
        const signerAddress = await this.signer.getAddress();
        await fundIfLocalNetwork([signerAddress]);

        const fee = await this.messageBridge.sendingFee();
        console.log('Current sending fee:', ethers.formatEther(fee), 'ETH');

        let result;
        try {
            result = await this.messageBridge.getEvmExecutionResult(nonce);
        } catch (e) {
            console.log('No execution result found for nonce', nonce);
            return;
        }
        console.log('Current execution result for nonce', nonce, ':', result);

        // Get and print the EVM to NeoN3 state root
        let evmToNeoState = await this.messageBridge.evmToNeoState();
        console.log('EVM to NeoN3 state root:', evmToNeoState.root);
        console.log('EVM to NeoN3 state nonce:', evmToNeoState.nonce.toString());

        // Get and print the NeoN3 to EVM state root
        const neoToEvmState = await this.messageBridge.neoToEvmState();
        console.log('NeoN3 to EVM state root:', neoToEvmState.root);
        console.log('NeoN3 to EVM state nonce:', neoToEvmState.nonce.toString());

        let txr = await this.messageBridge.sendResultMessage(nonce, {value: fee, ...DEFAULT_TX_OVERRIDES});

        const response = await txr.wait();
        console.log("Result message sent. Transaction hash:", txr.hash);
        console.log("Transaction mined. Status:", response?.status ?? 'unknown');

        // Get and print the updated EVM to NeoN3 state root
        evmToNeoState = await this.messageBridge.evmToNeoState();
        console.log('New EVM to NeoN3 state root:', evmToNeoState.root);
        console.log('New EVM to NeoN3 state nonce:', evmToNeoState.nonce.toString());
    }

    /**
     * Get the execution result of a message
     */
    async getEvmExecutionResult(nonce: bigint) {
        const result = await this.messageBridge.getEvmExecutionResult(nonce);
        console.log(`EVM execution result for nonce ${nonce} - Success: ${result.success}, Data: ${result.returnData}`);
        return result;
    }

    /**
     * Get the Neo execution result nonce and result
     */
    async getNeoExecutionResult(nonce: bigint) {
        try {
            const neoNonce = await this.messageBridge.getNeoExecutionResultNonce(nonce);
            const neoResult = await this.messageBridge.getNeoExecutionResult(neoNonce);
            console.log(`NeoN3 execution result (nonce ${neoNonce}): ${neoResult}`);
            return {neoNonce, neoResult};
        } catch (error) {
            console.error(`Error getting Neo execution result for nonce ${nonce}:`, error);
            throw error;
        }
    }

    /**
     * Get a stored message by nonce
     */
    async getMessage(nonce: bigint): Promise<AMBStorage.StoredMessageStructOutput> {
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
     * Get the current sending fee
     */
    async getSendingFee(): Promise<bigint> {
        const fee = await this.messageBridge.sendingFee();
        console.log(`Current sending fee: ${ethers.formatEther(fee)} ETH`);
        return fee;
    }
}

export function getNonceFromEnv() {
    const envNonce = process.env.NONCE;
    if (!envNonce) {
        throw new Error('Please set the NONCE environment variable');
    }

    const nonce = parseInt(envNonce, 10);
    if (isNaN(nonce)) {
        throw new Error('NONCE must be a valid number');
    }
    return BigInt(nonce);
}

/**
 * Helper function to encode an EVM call for executable messages
 */
export function encodeEvmCall(target: string, allowFailure: boolean = false, value: bigint = 0n, callData: string): string {
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


export function decodeMessageBridgeError(errorData: string): string {
    if (!errorData || errorData === '0x') {
        return 'No error data available';
    }

    try {
        const messageBridgeInterface = MessageBridge__factory.createInterface();
        const decodedError = messageBridgeInterface.parseError(errorData);

        if (decodedError) {
            // Format the decoded error with parameters
            const args = decodedError.args.length > 0 ? `(${decodedError.args.join(', ')})` : '()';
            return `${decodedError.name}${args}`;
        } else {
            return `Unknown error with data: ${errorData}`;
        }
    } catch (e) {
        return `Failed to decode error: ${errorData}`;
    }
}

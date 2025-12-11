import { ethers } from "hardhat";
import { Signer, TransactionReceipt } from 'ethers';
import { fundIfLocalNetwork } from "./network";
import { DEFAULT_TX_OVERRIDES } from "./constants";
import { TestBridge, TestToken } from '../../typechain-types';
import { getBridgeFromEnv } from "./addresses";

/**
 * Bridge deposit data structure matching BridgeLib.DepositData
 */
export interface DepositData {
    nonce: bigint;
    to: string;
    amount: bigint;
}

/**
 * Signature structure matching BridgeLib.Signature
 */
export interface BridgeSignature {
    v: number;
    r: string;
    s: string;
}

/**
 * Options for depositing native tokens
 */
export interface NativeDepositOptions {
    /** The new deposit root */
    depositRoot: string;
    /** Array of validator signatures */
    signatures: BridgeSignature[];
    /** Array of deposit data */
    deposits: DepositData[];
    /** Whether to fund the sender if on local network */
    autoFund?: boolean;
}

/**
 * Options for depositing ERC20 tokens
 */
export interface TokenDepositOptions {
    /** The token contract address */
    tokenAddress: string;
    /** The new deposit root */
    depositRoot: string;
    /** Array of validator signatures */
    signatures: BridgeSignature[];
    /** Array of deposit data */
    deposits: DepositData[];
    /** Whether to fund the sender if on local network */
    autoFund?: boolean;
}

/**
 * Result of a bridge deposit operation
 */
export interface DepositResult {
    /** Transaction hash */
    txHash: string;
    /** Transaction receipt */
    receipt: TransactionReceipt;
    /** Number of deposits processed */
    depositsProcessed: number;
}

/**
 * Utility class for interacting with Bridge contracts
 */
export class BridgeWrapper {
    private bridge: TestBridge;
    private signer: Signer;

    private constructor(bridge: TestBridge, signer: Signer) {
        this.bridge = bridge.connect(signer) as TestBridge;
        this.signer = signer;
    }

    /**
     * Create a new BridgeWrapper instance from environment variables
     */
    static async createFromEnv(signer: Signer): Promise<BridgeWrapper> {
        const bridge = await getBridgeFromEnv(signer.provider!);
        return new BridgeWrapper(bridge, signer);
    }

    /**
     * Create a new BridgeWrapper instance from a specific address
     */
    static async createFromAddress(bridgeAddress: string, signer: Signer): Promise<BridgeWrapper> {
        const bridge = (await ethers.getContractAt("TestBridge", bridgeAddress, signer)) as unknown as TestBridge;
        return new BridgeWrapper(bridge, signer);
    }

    /**
     * Deposit native tokens to the bridge
     */
    async depositNative(options: NativeDepositOptions): Promise<DepositResult> {
        const {
            depositRoot,
            signatures,
            deposits,
            autoFund = true
        } = options;

        // Auto-fund if on local network
        if (autoFund) {
            const signerAddress = await this.signer.getAddress();
            await fundIfLocalNetwork([signerAddress]);
        }

        console.log(`Depositing ${deposits.length} native token deposit(s)...`);
        console.log(`Deposit root: ${depositRoot}`);
        console.log(`Total amount: ${ethers.formatEther(deposits.reduce((sum, d) => sum + d.amount, 0n))} ETH`);

        const tx = await this.bridge.depositNative(
            depositRoot,
            signatures,
            deposits,
            DEFAULT_TX_OVERRIDES
        );

        const receipt = await tx.wait();
        if (!receipt) {
            throw new Error('Transaction failed');
        }

        console.log(`✅ Native deposits completed. Transaction: ${receipt.hash}`);
        console.log(`Gas used: ${receipt.gasUsed}`);

        return {
            txHash: receipt.hash,
            receipt,
            depositsProcessed: deposits.length
        };
    }

    /**
     * Deposit ERC20 tokens to the bridge
     */
    async depositToken(options: TokenDepositOptions): Promise<DepositResult> {
        const {
            tokenAddress,
            depositRoot,
            signatures,
            deposits,
            autoFund = true
        } = options;

        // Auto-fund if on local network
        if (autoFund) {
            const signerAddress = await this.signer.getAddress();
            await fundIfLocalNetwork([signerAddress]);
        }

        // Get token info for logging
        const token = (await ethers.getContractAt("TestToken", tokenAddress)) as unknown as TestToken;
        const tokenSymbol = await token.symbol();
        const tokenDecimals = await token.decimals();

        console.log(`Depositing ${deposits.length} ${tokenSymbol} token deposit(s)...`);
        console.log(`Token address: ${tokenAddress}`);
        console.log(`Deposit root: ${depositRoot}`);

        const totalAmount = deposits.reduce((sum, d) => sum + d.amount, 0n);
        console.log(`Total amount: ${ethers.formatUnits(totalAmount, tokenDecimals)} ${tokenSymbol}`);

        const tx = await this.bridge.depositToken(
            tokenAddress,
            depositRoot,
            signatures,
            deposits,
            DEFAULT_TX_OVERRIDES
        );

        const receipt = await tx.wait();
        if (!receipt) {
            throw new Error('Transaction failed');
        }

        console.log(`✅ ${tokenSymbol} token deposits completed. Transaction: ${receipt.hash}`);
        console.log(`Gas used: ${receipt.gasUsed}`);

        return {
            txHash: receipt.hash,
            receipt,
            depositsProcessed: deposits.length
        };
    }

    /**
     * Check if the bridge is paused
     */
    async isBridgePaused(): Promise<boolean> {
        return await this.bridge.bridgePaused();
    }

    /**
     * Check if native bridge is set and not paused
     */
    async isNativeBridgeReady(): Promise<boolean> {
        const isSet = await this.bridge.nativeBridgeIsSet();
        if (!isSet) return false;

        // Check that withdrawals are not paused
        const withdrawalsPaused = await this.bridge.getWithdrawalsPaused();
        return !withdrawalsPaused;
    }

    /**
     * Check if a token is registered
     */
    async isTokenRegistered(tokenAddress: string): Promise<boolean> {
        return await this.bridge.isRegisteredToken(tokenAddress);
    }
}

/**
 * Helper function to create mock validator signatures for testing
 * In production, these would come from actual validators
 */
export function createMockSignatures(count: number = 3): BridgeSignature[] {
    const signatures: BridgeSignature[] = [];

    for (let i = 0; i < count; i++) {
        signatures.push({
            v: 27,
            r: ethers.keccak256(ethers.toUtf8Bytes(`mock_signature_r_${i}`)),
            s: ethers.keccak256(ethers.toUtf8Bytes(`mock_signature_s_${i}`))
        });
    }

    return signatures;
}

/**
 * Helper function to create mock deposit data for testing
 */
export function createMockDepositData(recipients: string[], amounts: bigint[], startNonce: bigint = 1n): DepositData[] {
    if (recipients.length !== amounts.length) {
        throw new Error('Recipients and amounts arrays must have the same length');
    }

    return recipients.map((recipient, index) => ({
        nonce: startNonce + BigInt(index),
        to: recipient,
        amount: amounts[index]
    }));
}

/**
 * Utility function to get nonce from environment variable
 */
export function getNonceFromEnv(): bigint {
    const nonce = process.env.NONCE;
    if (!nonce) {
        throw new Error('NONCE environment variable is not set');
    }
    return BigInt(nonce);
}

/**
 * Decode bridge error from transaction data
 */
export function decodeBridgeError(errorData: string): string {
    try {
        const bridgeInterface = new ethers.Interface([
            'error InvalidDepositsLength()',
            'error InvalidNonceSequence()',
            'error InvalidRoot()',
            'error InvalidValidatorSignatures()',
            'error BridgePaused()',
            'error WithdrawalsPaused()',
            'error NonexistentClaimable()',
            'error TransferFailed()',
            'error InvalidTokenAddress()',
            'error InvalidTokenConfig()',
            'error AmountBelowMinAmount(uint256 minAmount, uint256 providedAmount)',
            'error AmountExceedsMaxAmount(uint256 maxAmount, uint256 providedAmount)',
            'error InsufficientFee(uint256 required, uint256 provided)',
            'error InvalidAddress()',
            'error InvalidAmount()',
            'error LengthMismatch()'
        ]);

        return bridgeInterface.parseError(errorData)?.name || 'Unknown error';
    } catch {
        return `Raw error data: ${errorData}`;
    }
}

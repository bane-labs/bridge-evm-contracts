import { ethers } from "hardhat";
import { MessageBridgeUtils, MessageType, encodeEvmCall, encodeStringMessage } from "../utils/messageBridgeUtils";
import { getOwner } from "../utils/wallet";

/**
 * Command-line script for sending messages to MessageBridge
 *
 * Usage:
 * npx hardhat run scripts/messages/sendMessage.ts --network <network>
 *
 * Environment Variables:
 * - MESSAGE_BRIDGE_ADDRESS: Address of the MessageBridge contract
 * - MESSAGE_TYPE: "executable" or "store-only"
 * - MESSAGE_DATA: Hex-encoded message data
 * - STORE_RESULT: "true" or "false" (for executable messages only)
 * - TARGET_CONTRACT: Contract address (for EVM calls)
 * - FUNCTION_SIGNATURE: Function signature (for EVM calls)
 * - FUNCTION_PARAMS: JSON array of function parameters (for EVM calls)
 * - ALLOW_FAILURE: "true" or "false" (for EVM calls)
 * - CALL_VALUE: ETH value to send with call (for EVM calls)
 */

interface ScriptConfig {
  messageBridgeAddress: string;
  messageType: "executable" | "store-only";
  messageData?: string;
  storeResult?: boolean;
  targetContract?: string;
  functionSignature?: string;
  functionParams?: any[];
  allowFailure?: boolean;
  callValue?: bigint;
}

function parseConfig(): ScriptConfig {
  const config: ScriptConfig = {
    messageBridgeAddress: process.env.MESSAGE_BRIDGE_ADDRESS || "",
    messageType: (process.env.MESSAGE_TYPE as "executable" | "store-only") || "store-only",
    messageData: process.env.MESSAGE_DATA,
    storeResult: process.env.STORE_RESULT !== "false",
    targetContract: process.env.TARGET_CONTRACT,
    functionSignature: process.env.FUNCTION_SIGNATURE,
    allowFailure: process.env.ALLOW_FAILURE === "true",
    callValue: process.env.CALL_VALUE ? ethers.parseEther(process.env.CALL_VALUE) : 0n
  };

  if (process.env.FUNCTION_PARAMS) {
    try {
      config.functionParams = JSON.parse(process.env.FUNCTION_PARAMS);
    } catch (error) {
      throw new Error("Invalid FUNCTION_PARAMS JSON format");
    }
  }

  return config;
}

function validateConfig(config: ScriptConfig): void {
  if (!config.messageBridgeAddress) {
    throw new Error("MESSAGE_BRIDGE_ADDRESS environment variable is required");
  }

  if (!ethers.isAddress(config.messageBridgeAddress)) {
    throw new Error("MESSAGE_BRIDGE_ADDRESS must be a valid Ethereum address");
  }

  if (!["executable", "store-only"].includes(config.messageType)) {
    throw new Error("MESSAGE_TYPE must be either 'executable' or 'store-only'");
  }

  // For executable messages, we need either messageData or contract call parameters
  if (config.messageType === "executable") {
    if (!config.messageData && (!config.targetContract || !config.functionSignature)) {
      throw new Error("For executable messages, provide either MESSAGE_DATA or (TARGET_CONTRACT + FUNCTION_SIGNATURE)");
    }

    if (config.targetContract && !ethers.isAddress(config.targetContract)) {
      throw new Error("TARGET_CONTRACT must be a valid Ethereum address");
    }
  }

  // For store-only messages, we need messageData
  if (config.messageType === "store-only" && !config.messageData) {
    throw new Error("For store-only messages, MESSAGE_DATA is required");
  }
}

function printUsage(): void {
  console.log(`
MessageBridge CLI Usage:

1. Store-only message with custom data:
   MESSAGE_BRIDGE_ADDRESS=0x... MESSAGE_TYPE=store-only MESSAGE_DATA=0x... npx hardhat run scripts/messages/sendMessage.ts

2. Store-only message with string:
   MESSAGE_BRIDGE_ADDRESS=0x... MESSAGE_TYPE=store-only MESSAGE_DATA="Hello World" npx hardhat run scripts/messages/sendMessage.ts

3. Executable message with custom data:
   MESSAGE_BRIDGE_ADDRESS=0x... MESSAGE_TYPE=executable MESSAGE_DATA=0x... STORE_RESULT=true npx hardhat run scripts/messages/sendMessage.ts

4. Executable message with ERC20 balanceOf call:
   MESSAGE_BRIDGE_ADDRESS=0x... MESSAGE_TYPE=executable TARGET_CONTRACT=0x... FUNCTION_SIGNATURE="balanceOf(address)" FUNCTION_PARAMS='["0x..."]' npx hardhat run scripts/messages/sendMessage.ts

5. Executable message with custom contract call:
   MESSAGE_BRIDGE_ADDRESS=0x... MESSAGE_TYPE=executable TARGET_CONTRACT=0x... FUNCTION_SIGNATURE="transfer(address,uint256)" FUNCTION_PARAMS='["0x...", "1000000000000000000"]' CALL_VALUE=0.1 npx hardhat run scripts/messages/sendMessage.ts

Environment Variables:
- MESSAGE_BRIDGE_ADDRESS: (Required) Address of the MessageBridge contract
- MESSAGE_TYPE: (Required) "executable" or "store-only"
- MESSAGE_DATA: Raw hex message data (alternative to contract call)
- STORE_RESULT: "true" or "false" (default: true, for executable only)
- TARGET_CONTRACT: Contract address for EVM calls
- FUNCTION_SIGNATURE: Function signature like "balanceOf(address)"
- FUNCTION_PARAMS: JSON array of function parameters
- ALLOW_FAILURE: "true" or "false" (default: false, for EVM calls)
- CALL_VALUE: ETH value to send with call (for EVM calls)
`);
}

async function main() {
  try {
    const config = parseConfig();
    validateConfig(config);

    console.log("MessageBridge Configuration:");
    console.log(`- Bridge Address: ${config.messageBridgeAddress}`);
    console.log(`- Message Type: ${config.messageType}`);
    console.log(`- Store Result: ${config.storeResult}`);

    const signer = getOwner(ethers.provider);
    console.log(`- Sender: ${await signer.getAddress()}\n`);

    const messageBridge = await MessageBridgeUtils.create(config.messageBridgeAddress, signer);

    let messageData: string;

    // Determine message data
    if (config.messageData) {
      // Use provided message data
      if (config.messageData.startsWith("0x")) {
        messageData = config.messageData;
      } else {
        // Treat as string and encode
        messageData = encodeStringMessage(config.messageData);
        console.log(`Encoded string message: ${messageData}`);
      }
    } else if (config.targetContract && config.functionSignature) {
      // Build EVM call
      console.log("Building EVM call:");
      console.log(`- Target: ${config.targetContract}`);
      console.log(`- Function: ${config.functionSignature}`);
      console.log(`- Parameters: ${JSON.stringify(config.functionParams || [])}`);
      console.log(`- Value: ${ethers.formatEther(config.callValue || 0n)} ETH`);
      console.log(`- Allow Failure: ${config.allowFailure}`);

      // Create interface and encode function call
      const functionInterface = new ethers.Interface([`function ${config.functionSignature}`]);
      const functionName = config.functionSignature.split("(")[0];
      const callData = functionInterface.encodeFunctionData(functionName, config.functionParams || []);

      messageData = encodeEvmCall(
        config.targetContract,
        callData,
        config.callValue || 0n,
        config.allowFailure || false
      );

      console.log(`Encoded EVM call: ${messageData}\n`);
    } else {
      throw new Error("No valid message data provided");
    }

    // Send the message
    const messageType = config.messageType === "executable" ? MessageType.EXECUTABLE : MessageType.STORE_ONLY;

    const result = await messageBridge.sendMessage({
      message: messageData,
      type: messageType,
      storeResult: config.storeResult
    });

    console.log("\nMessage sent successfully!");
    console.log(`Transaction Hash: ${result.txHash}`);
    console.log(`Message Nonce: ${result.nonce}`);
    console.log(`Gas Used: ${result.receipt.gasUsed}`);


  } catch (error) {
    console.error("Error:", error instanceof Error ? error.message : String(error));
    console.log("\n");
    printUsage();
    process.exitCode = 1;
  }
}

// Export for use as a library
export { main as sendMessage };

// Run if executed directly
if (require.main === module) {
  main();
}

import {ethers} from 'hardhat';
import {encodeStringMessage, MessageBridgeUtils, MessageType} from '../utils/messageBridgeUtils';
import {getPersonalWallet} from '../utils/wallet';

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
 */

interface ScriptConfig {
  messageBridgeAddress: string;
  messageType: "executable" | "store-only";
  messageData?: string;
  storeResult?: boolean;
}

function parseConfig(): ScriptConfig {
  return {
    messageBridgeAddress: process.env.MESSAGE_BRIDGE_ADDRESS || '',
    messageType: (process.env.MESSAGE_TYPE as 'executable' | 'store-only') || 'store-only',
    messageData: process.env.MESSAGE_DATA,
    storeResult: process.env.STORE_RESULT !== 'false',
  };
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

  // For both executable and store-only messages, we need messageData
  if (!config.messageData) {
    throw new Error('MESSAGE_DATA is required');
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

Environment Variables:
- MESSAGE_BRIDGE_ADDRESS: (Required) Address of the MessageBridge contract
- MESSAGE_TYPE: (Required) "executable" or "store-only"
- MESSAGE_DATA: (Required) Raw hex message data or string
- STORE_RESULT: "true" or "false" (default: true, for executable only)
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

    const signer = getPersonalWallet(ethers.provider);
    console.log(`- Sender: ${await signer.getAddress()}\n`);

    const messageBridge = await MessageBridgeUtils.create(config.messageBridgeAddress, signer);

    let messageData: string;

    // Use provided message data
    if (config.messageData.startsWith('0x')) {
      messageData = config.messageData;
    } else {
      // Treat as string and encode
      messageData = encodeStringMessage(config.messageData);
      console.log(`Encoded string message: ${messageData}`);
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

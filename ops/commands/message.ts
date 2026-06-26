import { ethers } from "ethers";
import { connectMessageBridge } from "../clients/messageBridge";
import { assertConfiguredChain, createProvider } from "../clients/provider";
import { loadOpsConfig, resolveMessageBridgeAddress } from "../config/load";
import { formatBool, printResolvedContext } from "../format";
import { CommandOptions, hasHelpFlag, isHelpFlag, parseOptions, requireOption } from "./options";
import { MessageBridge__factory } from "../../typechain-types";

const METADATA_TYPES = ["EXECUTABLE", "STORE_ONLY", "RESULT"] as const;

export async function runMessageCommand(args: string[]): Promise<void> {
  const [command, ...rest] = args;
  if (!command || isHelpFlag(command) || hasHelpFlag(rest)) {
    printMessageHelp();
    return;
  }

  const options = parseOptions(rest);
  const network = requireOption(options, "network");
  const config = loadOpsConfig(network);

  if (command === "state") {
    await messageState(config, options);
    return;
  }
  if (command === "get") {
    await messageGet(config, options);
    return;
  }
  if (command === "result") {
    await messageResult(config, options);
    return;
  }
  if (command === "executable") {
    await messageExecutable(config, options);
    return;
  }

  throw new Error(`Unknown message command: ${command}`);
}

function printMessageHelp(): void {
  console.log(`Message bridge commands

Usage:
  npm run ops -- message state --network <network> [--message-bridge <address>]
  npm run ops -- message get --network <network> --nonce <nonce> [--message-bridge <address>]
  npm run ops -- message result --network <network> --nonce <nonce> [--message-bridge <address>]
  npm run ops -- message executable --network <network> --nonce <nonce> [--message-bridge <address>]

Commands:
  state        Print message bridge state and config.
  get          Print one stored EVM message and decoded metadata.
  result       Print execution result state for one related message nonce.
  executable   Print executable state for one stored executable message.

Options:
  --network           Required. One of local, neox-devnet, neox-testnet, neox-mainnet.
  --message-bridge    Optional message bridge address override.
  --nonce             Message nonce.
`);
}

async function messageState(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const messageBridgeAddress = resolveMessageBridgeAddress(config, options["message-bridge"]);
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const messageBridge = connectMessageBridge(messageBridgeAddress, provider);
  printResolvedContext(config, { MessageBridge: messageBridgeAddress });

  const [
    management,
    executionManager,
    bridgePaused,
    sendingPaused,
    executingPaused,
    unclaimedFees,
    sendingFee,
    maxMessageSize,
    maxNrMessages,
    executionWindowSeconds,
    neoToEvmState,
    evmToNeoState
  ] = await Promise.all([
    messageBridge.management(),
    messageBridge.executionManager(),
    messageBridge.messageBridgePaused(),
    messageBridge.sendingPaused(),
    messageBridge.executingPaused(),
    messageBridge.unclaimedFees(),
    messageBridge.sendingFee(),
    messageBridge.maxMessageSize(),
    messageBridge.maxNrMessages(),
    messageBridge.executionWindowSeconds(),
    messageBridge.neoToEvmState(),
    messageBridge.evmToNeoState()
  ]);

  console.log("Message bridge");
  console.log(`  Management:          ${management}`);
  console.log(`  Execution manager:   ${executionManager}`);
  console.log(`  Bridge paused:       ${formatBool(bridgePaused)}`);
  console.log(`  Sending paused:      ${formatBool(sendingPaused)}`);
  console.log(`  Executing paused:    ${formatBool(executingPaused)}`);
  console.log(`  Unclaimed fees:      ${ethers.formatEther(unclaimedFees)} (${unclaimedFees.toString()} raw)`);
  console.log("");

  console.log("Config");
  console.log(`  Sending fee:         ${ethers.formatEther(sendingFee)} (${sendingFee.toString()} raw)`);
  console.log(`  Max message size:    ${maxMessageSize.toString()} bytes`);
  console.log(`  Max nr messages:     ${maxNrMessages.toString()}`);
  console.log(`  Execution window:    ${executionWindowSeconds.toString()} seconds`);
  console.log("");

  console.log("Neo -> EVM state");
  printState(neoToEvmState, "  ");
  console.log("");

  console.log("EVM -> Neo state");
  printState(evmToNeoState, "  ");
}

async function messageGet(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const messageBridgeAddress = resolveMessageBridgeAddress(config, options["message-bridge"]);
  const nonce = parseNonce(requireOption(options, "nonce"));
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const messageBridge = connectMessageBridge(messageBridgeAddress, provider);
  printResolvedContext(config, { MessageBridge: messageBridgeAddress, Nonce: nonce.toString() });

  const message = await messageBridge.getEvmMessage(nonce);
  console.log("Message");
  if (isEmptyBytes(message.encodedMetadata) && isEmptyBytes(message.rawMessage)) {
    console.log("  Found:             no");
    return;
  }

  console.log("  Found:             yes");
  console.log(`  Encoded metadata:  ${message.encodedMetadata}`);
  console.log(`  Raw message:       ${message.rawMessage}`);
  printDecodedMetadata(message.encodedMetadata);
}

async function messageResult(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const messageBridgeAddress = resolveMessageBridgeAddress(config, options["message-bridge"]);
  const nonce = parseNonce(requireOption(options, "nonce"));
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const messageBridge = connectMessageBridge(messageBridgeAddress, provider);
  printResolvedContext(config, { MessageBridge: messageBridgeAddress, Nonce: nonce.toString() });

  console.log("EVM execution result");
  try {
    const result = await messageBridge.getEvmExecutionResult(nonce);
    printResult(result, "  ");
  } catch (error) {
    printUnavailable(error, "  ");
  }

  const neoResultNonce = await messageBridge.getNeoExecutionResultNonce(nonce);
  const neoResult = await messageBridge.getNeoExecutionResult(nonce);
  console.log("");
  console.log("Neo execution result");
  console.log(`  Result nonce:      ${neoResultNonce.toString()}`);
  console.log(`  Raw result:        ${neoResult}`);
}

async function messageExecutable(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const messageBridgeAddress = resolveMessageBridgeAddress(config, options["message-bridge"]);
  const nonce = parseNonce(requireOption(options, "nonce"));
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const messageBridge = connectMessageBridge(messageBridgeAddress, provider);
  printResolvedContext(config, { MessageBridge: messageBridgeAddress, Nonce: nonce.toString() });

  console.log("Executable state");
  try {
    const executableState = await messageBridge.getExecutableState(nonce);
    printExecutableState(executableState, "  ");
  } catch (error) {
    printUnavailable(error, "  ");
  }
}

function printState(state: { nonce: bigint; root: string }, indent = ""): void {
  console.log(`${indent}Nonce:              ${state.nonce.toString()}`);
  console.log(`${indent}Root:               ${state.root}`);
}

function printDecodedMetadata(encodedMetadata: string): void {
  if (isEmptyBytes(encodedMetadata)) return;

  console.log("");
  console.log("Decoded metadata");
  try {
    const decoded = decodeMetadata(encodedMetadata);
    console.log(`  Type:              ${decoded.type}`);
    console.log(`  Timestamp:         ${decoded.timestamp.toString()} (${formatTimestamp(decoded.timestamp)})`);
    console.log(`  Sender:            ${decoded.sender}`);
    if (decoded.storeResult !== undefined) console.log(`  Store result:      ${formatBool(decoded.storeResult)}`);
    if (decoded.relatedMessageNonce !== undefined) {
      console.log(`  Related nonce:     ${decoded.relatedMessageNonce.toString()}`);
    }
  } catch (error) {
    console.log(`  Decode failed:     ${error instanceof Error ? error.message : String(error)}`);
  }
}

function decodeMetadata(encodedMetadata: string): {
  type: string;
  timestamp: bigint;
  sender: string;
  storeResult?: boolean;
  relatedMessageNonce?: bigint;
} {
  const coder = ethers.AbiCoder.defaultAbiCoder();
  const [messageType] = coder.decode(["uint8"], encodedMetadata) as unknown as [bigint];
  const typeId = Number(messageType);
  const type = METADATA_TYPES[typeId];
  if (!type) throw new Error(`unknown metadata type ${messageType.toString()}`);

  if (type === "EXECUTABLE") {
    const [metadata] = coder.decode(
      ["tuple(uint8 msgType,uint256 timestamp,address sender,bool storeResult)"],
      encodedMetadata
    ) as unknown as [{ timestamp: bigint; sender: string; storeResult: boolean }];
    return { type, timestamp: metadata.timestamp, sender: metadata.sender, storeResult: metadata.storeResult };
  }

  if (type === "STORE_ONLY") {
    const [metadata] = coder.decode(
      ["tuple(uint8 msgType,uint256 timestamp,address sender)"],
      encodedMetadata
    ) as unknown as [{ timestamp: bigint; sender: string }];
    return { type, timestamp: metadata.timestamp, sender: metadata.sender };
  }

  const [metadata] = coder.decode(
    ["tuple(uint8 msgType,uint256 timestamp,address sender,uint256 relatedMessageNonce)"],
    encodedMetadata
  ) as unknown as [{ timestamp: bigint; sender: string; relatedMessageNonce: bigint }];
  return {
    type,
    timestamp: metadata.timestamp,
    sender: metadata.sender,
    relatedMessageNonce: metadata.relatedMessageNonce
  };
}

function printResult(result: { success: boolean; returnData: string }, indent = ""): void {
  console.log(`${indent}Found:             yes`);
  console.log(`${indent}Success:           ${formatBool(result.success)}`);
  console.log(`${indent}Return data:       ${result.returnData}`);
}

function printExecutableState(state: { executed: boolean; expirationTimestamp: bigint }, indent = ""): void {
  console.log(`${indent}Found:             yes`);
  console.log(`${indent}Executed:          ${formatBool(state.executed)}`);
  console.log(`${indent}Expiration:        ${state.expirationTimestamp.toString()} (${formatTimestamp(state.expirationTimestamp)})`);
}

function printUnavailable(error: unknown, indent = ""): void {
  if (!ethers.isCallException(error)) throw error;
  console.log(`${indent}Found:             no`);
  console.log(`${indent}Reason:            ${decodeMessageBridgeError(error.data)}`);
}

function decodeMessageBridgeError(errorData: string | null): string {
  if (!errorData || errorData === "0x") return "call reverted";
  try {
    const decodedError = MessageBridge__factory.createInterface().parseError(errorData);
    if (!decodedError) return `unknown error (${errorData})`;
    const args = decodedError.args.length > 0 ? `(${decodedError.args.map((arg) => arg.toString()).join(", ")})` : "";
    return `${decodedError.name}${args}`;
  } catch {
    return `unknown error (${errorData})`;
  }
}

function formatTimestamp(timestamp: bigint): string {
  if (timestamp === 0n) return "not set";
  if (timestamp > 100_000_000_000n) {
    return `${new Date(Number(timestamp)).toISOString()}, interpreted as milliseconds`;
  }
  return new Date(Number(timestamp) * 1000).toISOString();
}

function parseNonce(value: string): bigint {
  if (!/^\d+$/.test(value)) throw new Error(`Invalid nonce: ${value}`);
  return BigInt(value);
}

function isEmptyBytes(value: string): boolean {
  return value === "0x";
}

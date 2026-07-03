import { ethers } from "ethers";
import { connectMessageBridge } from "../clients/messageBridge";
import { assertConfiguredChain, createProvider } from "../clients/provider";
import { loadOpsConfig, resolveMessageBridgeAddress } from "../config/load";
import { formatBool, printResolvedContext } from "../format";
import { createWriteContext, WriteContext } from "../tx/context";
import { parseYesFlag, requireMainnetConfirmation } from "../tx/guards";
import { parseBooleanOption, parseBytes, parseNonce } from "../tx/parse";
import { printTransactionReceipt } from "../tx/receipt";
import { parseDryRunFlag, runTransactionRequest } from "../tx/send";
import { printTransactionSummary } from "../tx/summary";
import { CommandOptions, hasHelpFlag, isHelpFlag, parseOptions, requireOption } from "./options";
import { messageSetSendingFee } from "./messageConfigure";
import { messageDecodeUint256, messageEncodeBalanceOf } from "./messageEncoding";
import { messagePause } from "./messagePause";
import { MessageBridge__factory } from "../../typechain-types";

const METADATA_TYPES = ["EXECUTABLE", "STORE_ONLY", "RESULT"] as const;

export async function runMessageCommand(args: string[]): Promise<void> {
  const [command, ...rest] = args;
  if (!command || isHelpFlag(command) || hasHelpFlag(rest)) {
    printMessageHelp();
    return;
  }

  const options = parseOptions(rest, new Set(["yes"]));
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
  if (command === "send-executable") {
    await messageSendExecutable(config, options);
    return;
  }
  if (command === "send-store-only") {
    await messageSendStoreOnly(config, options);
    return;
  }
  if (command === "send-result") {
    await messageSendResult(config, options);
    return;
  }
  if (command === "execute") {
    await messageExecute(config, options);
    return;
  }
  if (command === "pause") {
    await messagePause(config, options, "pause");
    return;
  }
  if (command === "unpause") {
    await messagePause(config, options, "unpause");
    return;
  }
  if (command === "set-sending-fee") {
    await messageSetSendingFee(config, options);
    return;
  }
  if (command === "encode-balance-of") {
    messageEncodeBalanceOf(config, options);
    return;
  }
  if (command === "decode-uint256") {
    messageDecodeUint256(options);
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
  npm run ops -- message send-executable --network <network> --account <name> --message <hex> --store-result <true|false> [--message-bridge <address>] [--dry-run true] [--yes]
  npm run ops -- message send-store-only --network <network> --account <name> --message <hex> [--message-bridge <address>] [--dry-run true] [--yes]
  npm run ops -- message send-result --network <network> --account <name> --related-nonce <nonce> [--message-bridge <address>] [--dry-run true] [--yes]
  npm run ops -- message execute --network <network> --account <name> --nonce <nonce> [--message-bridge <address>] [--value <eth>] [--dry-run true] [--yes]
  npm run ops -- message pause --network <network> --account <name> --target <bridge|sending|executing|all> [--message-bridge <address>] [--dry-run true] [--yes]
  npm run ops -- message unpause --network <network> --account <name> --target <bridge|sending|executing|all> [--message-bridge <address>] [--dry-run true] [--yes]
  npm run ops -- message set-sending-fee --network <network> --account <name> --amount <eth> [--message-bridge <address>] [--dry-run true] [--yes]
  npm run ops -- message encode-balance-of --network <network> --token <alias-or-address> --holder <address> [--allow-failure true] [--value <eth>]
  npm run ops -- message decode-uint256 --network <network> --data <hex>

Commands:
  state        Print message bridge state and config.
  get          Print one stored EVM message and decoded metadata.
  result       Print execution result state for one related message nonce.
  executable   Print executable state for one stored executable message.
  send-executable  Send an executable EVM -> Neo message.
  send-store-only  Send a store-only EVM -> Neo message.
  send-result      Send a result message for an executed Neo -> EVM message.
  execute          Execute one stored Neo -> EVM executable message.
  pause            Pause message bridge, sending, executing, or all targets.
  unpause          Unpause message bridge, sending, executing, or all targets.
  set-sending-fee  Set the message bridge sending fee.
  encode-balance-of  Encode an executable ERC20 balanceOf message.
  decode-uint256     Decode a uint256 result payload.

Options:
  --network           Required. One of local, neox-devnet, neox-testnet, neox-mainnet, neox-mainnet-fork.
  --account           Required for write commands. Account alias from config/accounts/<network>.json.
  --message-bridge    Optional message bridge address override.
  --nonce             Message nonce.
  --related-nonce     Related message nonce for result messages.
  --message           Hex-encoded raw message bytes.
  --store-result      true or false for executable message result storage.
  --target            bridge, sending, executing, or all.
  --amount            Fee amount in native ether units.
  --value             Native value in ether to forward when executing a message.
  --token             Token alias from deployment config or direct token address.
  --holder            Address used as balanceOf holder.
  --allow-failure     true or false for encoded executable calls.
  --data              Hex-encoded result bytes.
  --dry-run           Use --dry-run true to print the transaction without sending.
  --yes               Required for mainnet write commands.
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
  console.log(`  Execution window:    ${formatDuration(executionWindowSeconds)} (${executionWindowSeconds.toString()} seconds raw)`);
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

async function messageSendExecutable(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const messageBridgeAddress = resolveMessageBridgeAddress(config, options["message-bridge"]);
  const accountName = requireOption(options, "account");
  const message = parseBytes(requireOption(options, "message"), "message");
  const storeResult = parseBooleanOption(requireOption(options, "store-result"), "--store-result");
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const messageBridge = connectMessageBridge(messageBridgeAddress, context.wallet);

  printResolvedContext(config, {
    MessageBridge: messageBridgeAddress,
    Account: accountName,
    Sender: context.sender
  });

  const sendingFee = await assertMessageSendingOpen(config, messageBridge);
  await assertMessageSize(config, messageBridge, message, "message");

  const request = await messageBridge.sendExecutableMessage.populateTransaction(message, storeResult, { value: sendingFee });
  printTransactionSummary(context, {
    contract: messageBridgeAddress,
    action: "sendExecutableMessage",
    args: {
      messageBytes: byteLength(message),
      storeResult
    },
    value: sendingFee,
    request,
    dryRun
  });
  await finishTransaction(config, context, request, dryRun, confirmed);
}

async function messageSendStoreOnly(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const messageBridgeAddress = resolveMessageBridgeAddress(config, options["message-bridge"]);
  const accountName = requireOption(options, "account");
  const message = parseBytes(requireOption(options, "message"), "message");
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const messageBridge = connectMessageBridge(messageBridgeAddress, context.wallet);

  printResolvedContext(config, {
    MessageBridge: messageBridgeAddress,
    Account: accountName,
    Sender: context.sender
  });

  const sendingFee = await assertMessageSendingOpen(config, messageBridge);
  await assertMessageSize(config, messageBridge, message, "message");

  const request = await messageBridge.sendStoreOnlyMessage.populateTransaction(message, { value: sendingFee });
  printTransactionSummary(context, {
    contract: messageBridgeAddress,
    action: "sendStoreOnlyMessage",
    args: {
      messageBytes: byteLength(message)
    },
    value: sendingFee,
    request,
    dryRun
  });
  await finishTransaction(config, context, request, dryRun, confirmed);
}

async function messageSendResult(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const messageBridgeAddress = resolveMessageBridgeAddress(config, options["message-bridge"]);
  const accountName = requireOption(options, "account");
  const relatedNonce = parseNonce(requireOption(options, "related-nonce"), "related-nonce");
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const messageBridge = connectMessageBridge(messageBridgeAddress, context.wallet);

  printResolvedContext(config, {
    MessageBridge: messageBridgeAddress,
    Account: accountName,
    Sender: context.sender,
    RelatedNonce: relatedNonce.toString()
  });

  const sendingFee = await assertMessageSendingOpen(config, messageBridge);
  const result = await getRequiredEvmExecutionResult(config, messageBridge, relatedNonce);
  const encodedResult = encodeExecutionResult(result);
  await assertMessageSize(config, messageBridge, encodedResult, "result message");

  console.log("Execution result");
  printResult(result, "  ");
  console.log("");

  const request = await messageBridge.sendResultMessage.populateTransaction(relatedNonce, { value: sendingFee });
  printTransactionSummary(context, {
    contract: messageBridgeAddress,
    action: "sendResultMessage",
    args: {
      relatedNonce,
      resultBytes: byteLength(encodedResult)
    },
    value: sendingFee,
    request,
    dryRun
  });
  await finishTransaction(config, context, request, dryRun, confirmed);
}

async function messageExecute(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const messageBridgeAddress = resolveMessageBridgeAddress(config, options["message-bridge"]);
  const accountName = requireOption(options, "account");
  const nonce = parseNonce(requireOption(options, "nonce"));
  const value = options.value ? parseEtherValue(options.value, "--value") : 0n;
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const messageBridge = connectMessageBridge(messageBridgeAddress, context.wallet);

  printResolvedContext(config, {
    MessageBridge: messageBridgeAddress,
    Account: accountName,
    Sender: context.sender,
    Nonce: nonce.toString()
  });

  const executableState = await assertMessageExecutable(config, messageBridge, context.provider, nonce);
  console.log("Executable state");
  printExecutableState(executableState, "  ");
  console.log("");

  const request = await messageBridge.executeMessage.populateTransaction(nonce, { value });
  printTransactionSummary(context, {
    contract: messageBridgeAddress,
    action: "executeMessage",
    args: {
      nonce
    },
    value,
    request,
    dryRun
  });
  await finishTransaction(config, context, request, dryRun, confirmed);
}

async function finishTransaction(
  config: ReturnType<typeof loadOpsConfig>,
  context: WriteContext,
  request: ethers.TransactionRequest,
  dryRun: boolean,
  confirmed: boolean
): Promise<void> {
  if (!dryRun) requireMainnetConfirmation(config, confirmed);

  const result = await runTransactionRequest(context, request, { dryRun });
  if (!result.sent) {
    console.log("Dry run complete. Transaction was not sent.");
    return;
  }
  printTransactionReceipt(result.receipt);
}

async function assertMessageSendingOpen(
  config: ReturnType<typeof loadOpsConfig>,
  messageBridge: ReturnType<typeof connectMessageBridge>
): Promise<bigint> {
  const [messageBridgePaused, sendingPaused, sendingFee] = await Promise.all([
    messageBridge.messageBridgePaused(),
    messageBridge.sendingPaused(),
    messageBridge.sendingFee()
  ]);

  if (messageBridgePaused) {
    throw new Error(`Message bridge is paused on ${config.networkName}; cannot send messages.`);
  }
  if (sendingPaused) {
    throw new Error(`Message sending is paused on ${config.networkName}; cannot send messages.`);
  }
  return sendingFee;
}

async function assertMessageSize(
  config: ReturnType<typeof loadOpsConfig>,
  messageBridge: ReturnType<typeof connectMessageBridge>,
  message: string,
  label: string
): Promise<void> {
  const maxMessageSize = await messageBridge.maxMessageSize();
  const size = byteLength(message);
  if (BigInt(size) > maxMessageSize) {
    throw new Error(`${label} is ${size} bytes, exceeding max message size ${maxMessageSize.toString()} on ${config.networkName}.`);
  }
}

async function getRequiredEvmExecutionResult(
  config: ReturnType<typeof loadOpsConfig>,
  messageBridge: ReturnType<typeof connectMessageBridge>,
  relatedNonce: bigint
): Promise<{ success: boolean; returnData: string }> {
  try {
    return await messageBridge.getEvmExecutionResult(relatedNonce);
  } catch (error) {
    if (!ethers.isCallException(error)) throw error;
    throw new Error(
      `Cannot send result for related nonce ${relatedNonce.toString()} on ${config.networkName}: ${decodeMessageBridgeError(error.data)}.`
    );
  }
}

async function assertMessageExecutable(
  config: ReturnType<typeof loadOpsConfig>,
  messageBridge: ReturnType<typeof connectMessageBridge>,
  provider: ethers.JsonRpcProvider,
  nonce: bigint
): Promise<{ executed: boolean; expirationTimestamp: bigint }> {
  const [executingPaused, executionManager] = await Promise.all([
    messageBridge.executingPaused(),
    messageBridge.executionManager()
  ]);

  if (executingPaused) {
    throw new Error(`Message execution is paused on ${config.networkName}; cannot execute message ${nonce.toString()}.`);
  }
  if (executionManager === ethers.ZeroAddress) {
    throw new Error(`Message execution manager is not configured on ${config.networkName}; cannot execute message ${nonce.toString()}.`);
  }

  let executableState: { executed: boolean; expirationTimestamp: bigint };
  try {
    executableState = await messageBridge.getExecutableState(nonce);
  } catch (error) {
    if (!ethers.isCallException(error)) throw error;
    throw new Error(`Cannot execute message ${nonce.toString()} on ${config.networkName}: ${decodeMessageBridgeError(error.data)}.`);
  }

  if (executableState.executed) {
    throw new Error(`Message ${nonce.toString()} was already executed on ${config.networkName}.`);
  }

  const latestBlock = await provider.getBlock("latest");
  if (latestBlock && BigInt(latestBlock.timestamp) > executableState.expirationTimestamp) {
    throw new Error(
      `Message ${nonce.toString()} execution window expired at ${formatTimestamp(executableState.expirationTimestamp)} on ${config.networkName}.`
    );
  }

  return executableState;
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

function formatDuration(seconds: bigint): string {
  if (seconds === 0n) return "0 seconds";

  const units: Array<[string, bigint]> = [
    ["day", 86_400n],
    ["hour", 3_600n],
    ["minute", 60n],
    ["second", 1n]
  ];
  let remaining = seconds;
  const parts: string[] = [];

  for (const [unit, size] of units) {
    const value = remaining / size;
    if (value === 0n) continue;
    parts.push(`${value.toString()} ${unit}${value === 1n ? "" : "s"}`);
    remaining %= size;
  }

  return parts.join(" ");
}

function isEmptyBytes(value: string): boolean {
  return value === "0x";
}

function parseEtherValue(value: string, label: string): bigint {
  let parsed: bigint;
  try {
    parsed = ethers.parseEther(value);
  } catch {
    throw new Error(`Invalid ${label}: ${value}`);
  }
  if (parsed < 0n) throw new Error(`Invalid ${label}: ${value}`);
  return parsed;
}

function byteLength(value: string): number {
  return ethers.getBytes(value).length;
}

function encodeExecutionResult(result: { success: boolean; returnData: string }): string {
  return ethers.AbiCoder.defaultAbiCoder().encode(
    ["tuple(bool success, bytes returnData)"],
    [{ success: result.success, returnData: result.returnData }]
  );
}

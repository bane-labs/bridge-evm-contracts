import { ethers } from "ethers";
import { connectBridge } from "../clients/bridge";
import { connectErc20Metadata } from "../clients/erc20";
import { assertConfiguredChain, createProvider } from "../clients/provider";
import { loadOpsConfig, resolveBridgeAddress, resolveTokenAddress } from "../config/load";
import { formatAmount, formatBool, isEmptyClaimable, printResolvedContext } from "../format";
import { createWriteContext, WriteContext } from "../tx/context";
import { parseAddress, parsePositiveAmount, parsePositiveInteger, parseNonce } from "../tx/parse";
import { printTransactionReceipt } from "../tx/receipt";
import { parseDryRunFlag, runTransactionRequest } from "../tx/send";
import { printTransactionSummary } from "../tx/summary";
import { parseYesFlag, requireMainnetConfirmation } from "../tx/guards";
import { CommandOptions, hasHelpFlag, isHelpFlag, parseOptions, requireOption } from "./options";

export async function runBridgeCommand(args: string[]): Promise<void> {
  const [command, ...rest] = args;
  if (!command || isHelpFlag(command) || hasHelpFlag(rest)) {
    printBridgeHelp();
    return;
  }
  const options = parseOptions(rest, new Set(["yes", "approve"]));
  const network = requireOption(options, "network");
  const config = loadOpsConfig(network);

  if (command === "state") {
    await bridgeState(config, options);
    return;
  }
  if (command === "claimable") {
    await bridgeClaimable(config, options);
    return;
  }
  if (command === "token") {
    await bridgeToken(config, options);
    return;
  }
  if (command === "claim-native") {
    await bridgeClaimNative(config, options);
    return;
  }
  if (command === "claim-token") {
    await bridgeClaimToken(config, options);
    return;
  }
  if (command === "withdraw-native") {
    await bridgeWithdrawNative(config, options);
    return;
  }
  if (command === "withdraw-token") {
    await bridgeWithdrawToken(config, options);
    return;
  }
  throw new Error(`Unknown bridge command: ${command ?? "(missing)"}`);
}

function printBridgeHelp(): void {
  console.log(`Bridge commands

Usage:
  npm run ops -- bridge state --network <network> [--bridge <address>] [--max-tokens <count>]
  npm run ops -- bridge token --network <network> --token <alias-or-address> [--bridge <address>]
  npm run ops -- bridge claimable --network <network> --nonce <nonce> [--token <alias-or-address>] [--bridge <address>]
  npm run ops -- bridge claim-native --network <network> --account <name> --nonce <nonce> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge claim-token --network <network> --account <name> --token <alias-or-address> --nonce <nonce> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge withdraw-native --network <network> --account <name> --to <address> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge withdraw-token --network <network> --account <name> --token <alias-or-address> --to <address> --amount <tokens> [--bridge <address>] [--approve] [--dry-run true] [--yes]

Commands:
  state       Print native bridge state and registered token bridges.
  token       Print state for one token bridge.
  claimable   Check native or token claimable state for one nonce.
  claim-native  Claim native funds for one nonce.
  claim-token   Claim token funds for one token and nonce.
  withdraw-native  Withdraw native funds to Neo N3.
  withdraw-token   Withdraw tokens to Neo N3.

Options:
  --network      Required. One of local, neox-devnet, neox-testnet, neox-mainnet.
  --account      Required for write commands. Account alias from config/accounts/<network>.json.
  --bridge       Optional bridge address override.
  --token        Token alias from deployment config or direct token address.
  --nonce        Claimable nonce.
  --to           Recipient address on Neo N3 represented as an address.
  --amount       Withdrawal amount, in native ether units or token units.
  --approve      For token withdrawals, approve token spending before withdrawing if needed.
  --max-tokens   Maximum registeredTokens(index) entries to read for state.
  --dry-run      Use --dry-run true to print the transaction without sending.
  --yes          Required for mainnet write commands.
`);
}

async function bridgeState(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const bridge = connectBridge(bridgeAddress, provider);
  printResolvedContext(config, { Bridge: bridgeAddress });

  const [management, bridgePaused, withdrawalsPaused, unclaimedRewards, nativeIsSet] = await Promise.all([
    bridge.management(),
    bridge.bridgePaused(),
    bridge.withdrawalsPaused(),
    bridge.unclaimedRewards(),
    bridge.nativeBridgeIsSet()
  ]);

  console.log("Bridge");
  console.log(`  Management:          ${management}`);
  console.log(`  Bridge paused:       ${formatBool(bridgePaused)}`);
  console.log(`  Withdrawals paused:  ${formatBool(withdrawalsPaused)}`);
  console.log(`  Unclaimed rewards:   ${ethers.formatEther(unclaimedRewards)} (${unclaimedRewards.toString()} raw)`);
  console.log("");

  console.log("Native bridge");
  console.log(`  Set:                 ${formatBool(nativeIsSet)}`);
  if (nativeIsSet) {
    const nativeBridge = await bridge.nativeBridge();
    printNativeBridge(nativeBridge);
  }

  console.log("");
  await printRegisteredTokens(config, bridge, provider, options);
}

async function bridgeClaimable(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const nonce = parseNonce(requireOption(options, "nonce"));
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const bridge = connectBridge(bridgeAddress, provider);

  if (options.token) {
    const tokenAddress = resolveTokenAddress(config, options.token);
    printResolvedContext(config, { Bridge: bridgeAddress, Token: tokenAddress, Nonce: nonce.toString() });
    const isRegistered = await bridge.isRegisteredToken(tokenAddress);
    console.log(`Token registered: ${formatBool(isRegistered)}`);
    if (!isRegistered) return;

    const [tokenBridge, claimable] = await Promise.all([
      bridge.tokenBridges(tokenAddress),
      bridge.tokenClaimables(tokenAddress, nonce)
    ]);
    const decimals = await resolveTokenDecimals(provider, tokenAddress, config.deployment.tokens?.[options.token]?.decimals);
    printTokenBridge(tokenBridge, decimals);
    printClaimable(claimable, decimals, "token");
    return;
  }

  printResolvedContext(config, { Bridge: bridgeAddress, Nonce: nonce.toString() });
  const nativeIsSet = await bridge.nativeBridgeIsSet();
  console.log(`Native bridge set: ${formatBool(nativeIsSet)}`);
  if (!nativeIsSet) return;

  const [nativeBridge, claimable] = await Promise.all([
    bridge.nativeBridge(),
    bridge.claimableNative(nonce)
  ]);
  printNativeBridge(nativeBridge);
  printClaimable(claimable, 8, "native");
}

async function bridgeToken(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const tokenInput = requireOption(options, "token");
  const tokenAddress = resolveTokenAddress(config, tokenInput);
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const bridge = connectBridge(bridgeAddress, provider);

  printResolvedContext(config, { Bridge: bridgeAddress, Token: tokenAddress });
  await printTokenState(config, bridge, provider, tokenAddress, tokenInput);
}

async function bridgeClaimNative(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const nonce = parseNonce(requireOption(options, "nonce"));
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);

  printResolvedContext(config, { Bridge: bridgeAddress, Account: accountName, Sender: context.sender, Nonce: nonce.toString() });

  await assertNativeClaimOpen(config, bridge);

  const claimable = await bridge.claimableNative(nonce);
  printClaimable(claimable, 8, "native");
  if (isEmptyClaimable(claimable)) {
    throw new Error(`No native claimable found for nonce ${nonce.toString()}`);
  }

  const request = await bridge.claimNative.populateTransaction(nonce);
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "claimNative",
    args: {
      nonce,
      recipient: claimable.to,
      amountRaw: claimable.amount
    },
    request,
    dryRun
  });
  if (!dryRun) requireMainnetConfirmation(config, confirmed);

  const result = await runTransactionRequest(context, request, { dryRun });
  if (!result.sent) {
    console.log("Dry run complete. Transaction was not sent.");
    return;
  }
  printTransactionReceipt(result.receipt);
}

async function bridgeClaimToken(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const tokenInput = requireOption(options, "token");
  const tokenAddress = resolveTokenAddress(config, tokenInput);
  const nonce = parseNonce(requireOption(options, "nonce"));
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);

  printResolvedContext(config, {
    Bridge: bridgeAddress,
    Account: accountName,
    Sender: context.sender,
    Token: tokenAddress,
    Nonce: nonce.toString()
  });

  const isRegistered = await bridge.isRegisteredToken(tokenAddress);
  console.log(`Token registered: ${formatBool(isRegistered)}`);
  if (!isRegistered) throw new Error(`Token ${tokenAddress} is not registered on ${config.networkName}`);

  await assertTokenClaimOpen(config, bridge, tokenAddress);

  const [claimable, decimals] = await Promise.all([
    bridge.tokenClaimables(tokenAddress, nonce),
    resolveTokenDecimals(context.provider, tokenAddress, config.deployment.tokens?.[tokenInput]?.decimals)
  ]);
  printClaimable(claimable, decimals, "token");
  if (isEmptyClaimable(claimable)) {
    throw new Error(`No token claimable found for token ${tokenAddress} and nonce ${nonce.toString()}`);
  }

  const request = await bridge.claimToken.populateTransaction(tokenAddress, nonce);
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "claimToken",
    args: {
      token: tokenAddress,
      nonce,
      recipient: claimable.to,
      amountRaw: claimable.amount
    },
    request,
    dryRun
  });
  if (!dryRun) requireMainnetConfirmation(config, confirmed);

  const result = await runTransactionRequest(context, request, { dryRun });
  if (!result.sent) {
    console.log("Dry run complete. Transaction was not sent.");
    return;
  }
  printTransactionReceipt(result.receipt);
}

async function bridgeWithdrawNative(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const recipient = parseRecipientAddress(requireOption(options, "to"));
  const amount = parsePositiveAmount(requireOption(options, "amount"), 18, "amount");
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);

  printResolvedContext(config, {
    Bridge: bridgeAddress,
    Account: accountName,
    Sender: context.sender,
    Recipient: recipient
  });

  const nativeBridge = await assertNativeWithdrawalOpen(config, bridge);
  assertWithdrawalAmount("Native withdrawal amount", amount, nativeBridge.config, 18);
  const totalValue = amount + nativeBridge.config.fee;
  await assertNativeBalance(context, totalValue, "native withdrawal amount plus fee");

  console.log("Native withdrawal");
  console.log(`  Amount:              ${formatAmount(amount, 18)} native`);
  console.log(`  Fee:                 ${ethers.formatEther(nativeBridge.config.fee)} (${nativeBridge.config.fee.toString()} wei)`);
  console.log(`  Total value:         ${ethers.formatEther(totalValue)} (${totalValue.toString()} wei)`);
  console.log("");

  const request = await bridge.withdrawNative.populateTransaction(recipient, nativeBridge.config.fee, { value: totalValue });
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "withdrawNative",
    args: {
      recipient,
      amountRaw: amount,
      maxFeeRaw: nativeBridge.config.fee
    },
    value: totalValue,
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

async function bridgeWithdrawToken(config: ReturnType<typeof loadOpsConfig>, options: CommandOptions): Promise<void> {
  const bridgeAddress = resolveBridgeAddress(config, options.bridge);
  const accountName = requireOption(options, "account");
  const tokenInput = requireOption(options, "token");
  const tokenAddress = resolveTokenAddress(config, tokenInput);
  const recipient = parseRecipientAddress(requireOption(options, "to"));
  const dryRun = parseDryRunFlag(options["dry-run"]);
  const confirmed = parseYesFlag(options.yes);
  const approve = parsePresenceFlag(options.approve);
  const context = await createWriteContext(config, accountName);
  const bridge = connectBridge(bridgeAddress, context.wallet);
  const token = connectErc20Metadata(tokenAddress, context.wallet);
  const decimals = await resolveTokenDecimals(context.provider, tokenAddress, config.deployment.tokens?.[tokenInput]?.decimals);
  const amount = parsePositiveAmount(requireOption(options, "amount"), decimals, "amount");

  printResolvedContext(config, {
    Bridge: bridgeAddress,
    Account: accountName,
    Sender: context.sender,
    Token: tokenAddress,
    Recipient: recipient
  });

  const tokenBridge = await assertTokenWithdrawalOpen(config, bridge, tokenAddress);
  assertWithdrawalAmount("Token withdrawal amount", amount, tokenBridge.config, decimals);
  await assertNativeBalance(context, tokenBridge.config.fee, "token withdrawal fee");

  const [tokenBalance, allowance] = await Promise.all([
    token.balanceOf(context.sender),
    token.allowance(context.sender, bridgeAddress)
  ]);

  console.log("Token withdrawal");
  console.log(`  Amount:              ${formatAmount(amount, decimals)}`);
  console.log(`  Fee:                 ${ethers.formatEther(tokenBridge.config.fee)} (${tokenBridge.config.fee.toString()} wei)`);
  console.log(`  Token balance:       ${formatAmount(tokenBalance, decimals)}`);
  console.log(`  Current allowance:   ${formatAmount(allowance, decimals)}`);
  console.log("");

  if (tokenBalance < amount) {
    throw new Error(`Insufficient token balance: need ${formatAmount(amount, decimals)}, have ${formatAmount(tokenBalance, decimals)}.`);
  }

  if (allowance < amount) {
    if (!approve) {
      throw new Error(`Token allowance is too low. Rerun with --approve to approve ${formatAmount(amount, decimals)} for ${bridgeAddress}.`);
    }

    const approveRequest = await token.approve.populateTransaction(bridgeAddress, amount);
    printTransactionSummary(context, {
      contract: tokenAddress,
      action: "approve",
      args: {
        spender: bridgeAddress,
        amountRaw: amount
      },
      request: approveRequest,
      dryRun
    });
    await finishBridgeTransaction(config, context, approveRequest, dryRun, confirmed);
  }

  const request = await bridge.withdrawToken.populateTransaction(tokenAddress, recipient, amount, { value: tokenBridge.config.fee });
  printTransactionSummary(context, {
    contract: bridgeAddress,
    action: "withdrawToken",
    args: {
      token: tokenAddress,
      recipient,
      amountRaw: amount
    },
    value: tokenBridge.config.fee,
    request,
    dryRun
  });
  await finishBridgeTransaction(config, context, request, dryRun, confirmed);
}

async function finishBridgeTransaction(
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

async function assertNativeClaimOpen(
  config: ReturnType<typeof loadOpsConfig>,
  bridge: ReturnType<typeof connectBridge>
): Promise<void> {
  const [bridgePaused, nativeIsSet] = await Promise.all([
    bridge.bridgePaused(),
    bridge.nativeBridgeIsSet()
  ]);

  if (bridgePaused) {
    throw new Error(`Bridge is paused on ${config.networkName}; cannot claim native funds.`);
  }
  if (!nativeIsSet) {
    throw new Error(`Native bridge is not configured on ${config.networkName}; cannot claim native funds.`);
  }

  const nativeBridge = await bridge.nativeBridge();
  if (nativeBridge.paused) {
    throw new Error(`Native bridge is paused on ${config.networkName}; cannot claim native funds.`);
  }
}

async function assertTokenClaimOpen(
  config: ReturnType<typeof loadOpsConfig>,
  bridge: ReturnType<typeof connectBridge>,
  tokenAddress: string
): Promise<void> {
  const bridgePaused = await bridge.bridgePaused();
  if (bridgePaused) {
    throw new Error(`Bridge is paused on ${config.networkName}; cannot claim token funds.`);
  }

  const tokenBridge = await bridge.tokenBridges(tokenAddress);
  if (tokenBridge.paused) {
    throw new Error(`Token bridge ${tokenAddress} is paused on ${config.networkName}; cannot claim token funds.`);
  }
}

async function assertNativeWithdrawalOpen(
  config: ReturnType<typeof loadOpsConfig>,
  bridge: ReturnType<typeof connectBridge>
): Promise<Awaited<ReturnType<ReturnType<typeof connectBridge>["nativeBridge"]>>> {
  const [bridgePaused, withdrawalsPaused, nativeIsSet] = await Promise.all([
    bridge.bridgePaused(),
    bridge.withdrawalsPaused(),
    bridge.nativeBridgeIsSet()
  ]);

  if (bridgePaused) {
    throw new Error(`Bridge is paused on ${config.networkName}; cannot withdraw native funds.`);
  }
  if (withdrawalsPaused) {
    throw new Error(`Withdrawals are paused on ${config.networkName}; cannot withdraw native funds.`);
  }
  if (!nativeIsSet) {
    throw new Error(`Native bridge is not configured on ${config.networkName}; cannot withdraw native funds.`);
  }

  const nativeBridge = await bridge.nativeBridge();
  if (nativeBridge.paused) {
    throw new Error(`Native bridge is paused on ${config.networkName}; cannot withdraw native funds.`);
  }
  return nativeBridge;
}

async function assertTokenWithdrawalOpen(
  config: ReturnType<typeof loadOpsConfig>,
  bridge: ReturnType<typeof connectBridge>,
  tokenAddress: string
): Promise<Awaited<ReturnType<ReturnType<typeof connectBridge>["tokenBridges"]>>> {
  const [bridgePaused, withdrawalsPaused, isRegistered] = await Promise.all([
    bridge.bridgePaused(),
    bridge.withdrawalsPaused(),
    bridge.isRegisteredToken(tokenAddress)
  ]);

  if (bridgePaused) {
    throw new Error(`Bridge is paused on ${config.networkName}; cannot withdraw token funds.`);
  }
  if (withdrawalsPaused) {
    throw new Error(`Withdrawals are paused on ${config.networkName}; cannot withdraw token funds.`);
  }
  if (!isRegistered) {
    throw new Error(`Token ${tokenAddress} is not registered on ${config.networkName}.`);
  }

  const tokenBridge = await bridge.tokenBridges(tokenAddress);
  if (tokenBridge.paused) {
    throw new Error(`Token bridge ${tokenAddress} is paused on ${config.networkName}; cannot withdraw token funds.`);
  }
  return tokenBridge;
}

function assertWithdrawalAmount(
  label: string,
  amount: bigint,
  config: { minAmount: bigint; maxAmount: bigint; decimalScalingFactor: bigint },
  decimals: number
): void {
  const scalingFactor = 10n ** config.decimalScalingFactor;
  if (amount % scalingFactor !== 0n) {
    throw new Error(`${label} must be divisible by ${scalingFactor.toString()} raw units.`);
  }
  if (amount < config.minAmount) {
    throw new Error(`${label} is below minimum: ${formatAmount(amount, decimals)} < ${formatAmount(config.minAmount, decimals)}.`);
  }
  if (amount > config.maxAmount) {
    throw new Error(`${label} exceeds maximum: ${formatAmount(amount, decimals)} > ${formatAmount(config.maxAmount, decimals)}.`);
  }
}

async function assertNativeBalance(context: WriteContext, required: bigint, label: string): Promise<void> {
  const balance = await context.provider.getBalance(context.sender);
  console.log(`Sender native balance: ${ethers.formatEther(balance)} (${balance.toString()} wei)`);
  if (balance < required) {
    throw new Error(`Insufficient native balance for ${label}: need ${ethers.formatEther(required)}, have ${ethers.formatEther(balance)}.`);
  }
}

function parsePresenceFlag(value: string | undefined): boolean {
  return value !== undefined;
}

function parseRecipientAddress(value: string): string {
  const recipient = parseAddress(value, "to");
  if (recipient === ethers.ZeroAddress) throw new Error("Invalid to: zero address");
  return recipient;
}

async function printRegisteredTokens(
  config: ReturnType<typeof loadOpsConfig>,
  bridge: ReturnType<typeof connectBridge>,
  provider: ethers.JsonRpcProvider,
  options: CommandOptions
): Promise<void> {
  const maxTokens = options["max-tokens"] ? parsePositiveInteger(options["max-tokens"], "max-tokens") : 100;

  console.log("Token bridges");
  const tokens = await discoverRegisteredTokens(bridge, maxTokens);
  if (tokens.length === 0) {
    console.log("  None registered");
    return;
  }
  if (tokens.length === maxTokens) {
    console.log(`  Reached --max-tokens ${maxTokens}; increase it if more registered tokens are expected.`);
  }

  for (let i = 0; i < tokens.length; i++) {
    const tokenAddress = tokens[i];
    console.log("");
    console.log(`  [${i}] ${tokenAddress}`);
    await printTokenState(config, bridge, provider, tokenAddress, tokenAddress, "    ");
  }
}

async function discoverRegisteredTokens(
  bridge: ReturnType<typeof connectBridge>,
  maxTokens: number
): Promise<string[]> {
  const tokens: string[] = [];
  for (let index = 0; index < maxTokens; index++) {
    try {
      tokens.push(ethers.getAddress(await bridge.registeredTokens(index)));
    } catch (error) {
      // registeredTokens(index) reverts when index is out of bounds; treat that as end-of-list.
      if (!ethers.isCallException(error)) throw error;
      break;
    }
  }
  return tokens;
}

async function printTokenState(
  config: ReturnType<typeof loadOpsConfig>,
  bridge: ReturnType<typeof connectBridge>,
  provider: ethers.Provider,
  tokenAddress: string,
  tokenInput: string,
  indent = ""
): Promise<void> {
  const isRegistered = await bridge.isRegisteredToken(tokenAddress);
  console.log(`${indent}Registered:          ${formatBool(isRegistered)}`);
  if (!isRegistered) return;

  const tokenBridge = await bridge.tokenBridges(tokenAddress);
  const configuredDecimals = config.deployment.tokens?.[tokenInput]?.decimals;
  const decimals = await resolveTokenDecimals(provider, tokenAddress, configuredDecimals);
  const metadata = await resolveTokenMetadata(provider, tokenAddress);
  if (metadata.symbol) console.log(`${indent}Symbol:              ${metadata.symbol}`);
  console.log(`${indent}Decimals:            ${decimals}`);
  console.log(`${indent}Neo N3 token:        ${tokenBridge.config.neoN3Token}`);
  printTokenBridge(tokenBridge, decimals, indent);
}

function printNativeBridge(nativeBridge: Awaited<ReturnType<ReturnType<typeof connectBridge>["nativeBridge"]>>): void {
  console.log(`  Paused:              ${formatBool(nativeBridge.paused)}`);
  console.log(`  Deposit nonce:       ${nativeBridge.depositState.nonce.toString()}`);
  console.log(`  Deposit root:        ${nativeBridge.depositState.root}`);
  console.log(`  Withdrawal nonce:    ${nativeBridge.withdrawalState.nonce.toString()}`);
  console.log(`  Withdrawal root:     ${nativeBridge.withdrawalState.root}`);
  console.log(`  Fee:                 ${ethers.formatEther(nativeBridge.config.fee)} (${nativeBridge.config.fee.toString()} raw)`);
  console.log(`  Min amount:          ${ethers.formatEther(nativeBridge.config.minAmount)} (${nativeBridge.config.minAmount.toString()} raw)`);
  console.log(`  Max amount:          ${ethers.formatEther(nativeBridge.config.maxAmount)} (${nativeBridge.config.maxAmount.toString()} raw)`);
  console.log(`  Max deposits:        ${nativeBridge.config.maxDeposits.toString()}`);
  console.log(`  Decimal scaling:     ${nativeBridge.config.decimalScalingFactor.toString()}`);
}

function printTokenBridge(tokenBridge: Awaited<ReturnType<ReturnType<typeof connectBridge>["tokenBridges"]>>, decimals: number, indent = ""): void {
  console.log(`${indent}Token bridge`);
  console.log(`${indent}  Paused:            ${formatBool(tokenBridge.paused)}`);
  console.log(`${indent}  Deposit nonce:     ${tokenBridge.depositState.nonce.toString()}`);
  console.log(`${indent}  Deposit root:      ${tokenBridge.depositState.root}`);
  console.log(`${indent}  Withdrawal nonce:  ${tokenBridge.withdrawalState.nonce.toString()}`);
  console.log(`${indent}  Withdrawal root:   ${tokenBridge.withdrawalState.root}`);
  console.log(`${indent}  Fee:               ${ethers.formatEther(tokenBridge.config.fee)} (${tokenBridge.config.fee.toString()} raw)`);
  console.log(`${indent}  Min amount:        ${formatAmount(tokenBridge.config.minAmount, decimals)}`);
  console.log(`${indent}  Max amount:        ${formatAmount(tokenBridge.config.maxAmount, decimals)}`);
  console.log(`${indent}  Max deposits:      ${tokenBridge.config.maxDeposits.toString()}`);
  console.log(`${indent}  Decimal scaling:   ${tokenBridge.config.decimalScalingFactor.toString()}`);
}

function printClaimable(claimable: { to: string; amount: bigint }, decimals: number, label: string): void {
  console.log("");
  console.log("Claimable");
  if (isEmptyClaimable(claimable)) {
    console.log("  Found:               no");
    return;
  }
  console.log("  Found:               yes");
  console.log(`  Recipient:           ${claimable.to}`);
  console.log(`  Amount:              ${formatAmount(claimable.amount, decimals)} ${label}`);
}

async function resolveTokenDecimals(provider: ethers.Provider, tokenAddress: string, configured?: number): Promise<number> {
  if (configured !== undefined) return configured;
  try {
    return Number(await connectErc20Metadata(tokenAddress, provider).decimals());
  } catch {
    return 18;
  }
}

async function resolveTokenMetadata(provider: ethers.Provider, tokenAddress: string): Promise<{ symbol?: string }> {
  try {
    const token = connectErc20Metadata(tokenAddress, provider);
    return { symbol: await token.symbol() };
  } catch {
    return {};
  }
}

import { ethers } from "ethers";
import { connectNeoToken } from "../clients/erc20";
import { assertConfiguredChain, createProvider } from "../clients/provider";
import { loadOpsConfig } from "../config/load";
import { formatAmount, printResolvedContext } from "../format";
import { hasHelpFlag, isHelpFlag, parseOptions, requireOption } from "./options";

export async function runNeoTokenCommand(args: string[]): Promise<void> {
  const [command, ...rest] = args;
  if (!command || isHelpFlag(command) || hasHelpFlag(rest)) {
    printNeoTokenHelp();
    return;
  }

  const options = parseOptions(rest);
  const network = requireOption(options, "network");
  const config = loadOpsConfig(network);
  const tokenAddress = resolveNeoTokenAddress(options["neo-token"] ?? config.deployment.contracts.neoToken);
  const provider = createProvider(config.network);
  await assertConfiguredChain(provider, config.network.chainId);
  const token = connectNeoToken(tokenAddress, provider);

  if (command === "state") {
    printResolvedContext(config, { NeoToken: tokenAddress });
    await printNeoTokenState(token);
    return;
  }
  if (command === "total-supply" || command === "supply") {
    printResolvedContext(config, { NeoToken: tokenAddress });
    await printTotalSupply(token);
    return;
  }
  if (command === "balance" || command === "balance-of") {
    const holder = parseAddress(requireOption(options, "holder"), "holder");
    printResolvedContext(config, { NeoToken: tokenAddress, Holder: holder });
    await printBalance(token, holder);
    return;
  }
  if (command === "owner") {
    printResolvedContext(config, { NeoToken: tokenAddress });
    await printOwner(token);
    return;
  }

  throw new Error(`Unknown neo-token command: ${command}`);
}

async function printNeoTokenState(token: ReturnType<typeof connectNeoToken>): Promise<void> {
  const [name, symbol, decimals, totalSupply, owner, pendingOwner] = await Promise.all([
    token.name(),
    token.symbol(),
    token.decimals(),
    token.totalSupply(),
    token.owner(),
    token.pendingOwner()
  ]);
  const decimalCount = Number(decimals);

  console.log("NeoToken");
  console.log(`  Name:          ${name}`);
  console.log(`  Symbol:        ${symbol}`);
  console.log(`  Decimals:      ${decimalCount}`);
  console.log(`  Total supply:  ${formatAmount(totalSupply, decimalCount)}`);
  console.log(`  Owner:         ${owner}`);
  console.log(`  Pending owner: ${pendingOwner}`);
}

async function printTotalSupply(token: ReturnType<typeof connectNeoToken>): Promise<void> {
  const [decimals, totalSupply] = await Promise.all([token.decimals(), token.totalSupply()]);
  console.log(`Total supply: ${formatAmount(totalSupply, Number(decimals))}`);
}

async function printBalance(token: ReturnType<typeof connectNeoToken>, holder: string): Promise<void> {
  const [decimals, balance] = await Promise.all([token.decimals(), token.balanceOf(holder)]);
  console.log(`Balance: ${formatAmount(balance, Number(decimals))}`);
}

async function printOwner(token: ReturnType<typeof connectNeoToken>): Promise<void> {
  const owner = await token.owner();
  console.log(`Owner: ${owner}`);
}

function resolveNeoTokenAddress(value?: string): string {
  if (!value) {
    throw new Error("NeoToken address is not configured. Set contracts.neoToken in config/deployments/<network>.json or pass --neo-token <address>.");
  }
  if (!ethers.isAddress(value)) throw new Error(`NeoToken address is invalid: ${value}`);
  return ethers.getAddress(value);
}

function parseAddress(value: string, label: string): string {
  if (!ethers.isAddress(value)) throw new Error(`Invalid --${label} address: ${value}`);
  return ethers.getAddress(value);
}

function printNeoTokenHelp(): void {
  console.log(`NeoToken commands

Usage:
  npm run ops -- neo-token state --network <network> [--neo-token <address>]
  npm run ops -- neo-token total-supply --network <network> [--neo-token <address>]
  npm run ops -- neo-token balance-of --network <network> --holder <address> [--neo-token <address>]
  npm run ops -- neo-token owner --network <network> [--neo-token <address>]

Commands:
  state           Print NeoToken metadata, total supply, and ownership.
  total-supply    Print NeoToken total supply.
  balance-of      Print NeoToken balance for one holder.
  owner           Print the NeoToken owner.

Options:
  --network    Required. One of local, neox-devnet, neox-testnet, neox-mainnet, neox-mainnet-fork.
  --neo-token  Optional NeoToken address override. Defaults to contracts.neoToken.
  --holder     Holder address for balance-of.
`);
}

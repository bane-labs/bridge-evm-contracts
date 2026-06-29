import { AccountCheckResult, accountSource, checkAccount, listAccounts, loadAccountAddress } from "../accounts/load";
import { loadOpsConfig } from "../config/load";
import { AccountSource } from "../config/types";
import { printResolvedContext } from "../format";
import { hasHelpFlag, isHelpFlag, parseOptions, requireOption } from "./options";

export async function runAccountsCommand(args: string[]): Promise<void> {
  const [command, ...rest] = args;
  if (!command || isHelpFlag(command) || hasHelpFlag(rest)) {
    printAccountsHelp();
    return;
  }
  const options = parseOptions(rest);
  const network = requireOption(options, "network");
  const config = loadOpsConfig(network);

  if (command === "list") {
    printResolvedContext(config);
    printAccounts(config);
    return;
  }
  if (command === "address") {
    const accountName = requireOption(options, "account");
    const source = accountSource(config, accountName);
    const address = await loadAccountAddress(config, accountName);
    printResolvedContext(config, { Account: accountName });
    printAccountAddress(accountName, source, address);
    return;
  }
  if (command === "check") {
    printResolvedContext(config, options.account ? { Account: options.account } : {});
    await checkAccounts(config, options.account);
    return;
  }

  throw new Error(`Unknown accounts command: ${command ?? "(missing)"}`);
}

function printAccountsHelp(): void {
  console.log(`Accounts commands

Usage:
  npm run ops -- accounts list --network <network>
  npm run ops -- accounts address --network <network> --account <name>
  npm run ops -- accounts check --network <network> [--account <name>]

Commands:
  list       Print configured account aliases and sources. Does not read secrets.
  address    Resolve one configured account address from privateKeyEnv or keystore.
  check      Validate configured account sources and print derived addresses.

Account config:
  Copy config/accounts/<network>.example.json to config/accounts/<network>.json.
  Local account config files are ignored by git.
`);
}

function printAccounts(config: ReturnType<typeof loadOpsConfig>): void {
  const accounts = listAccounts(config);

  console.log("Accounts");
  if (accounts.length === 0) {
    console.log(`  None configured. Create config/accounts/${config.networkName}.json from the example file if write ops need accounts.`);
    return;
  }

  for (const account of accounts) {
    console.log(`  ${account.name}`);
    console.log(`    Type:        ${account.type}`);
    console.log(`    Source:      ${account.source}`);
    if (account.resolvedPath && account.resolvedPath !== account.source) {
      console.log(`    Resolved:    ${account.resolvedPath}`);
    }
    if (account.passwordEnv) console.log(`    Password env: ${account.passwordEnv}`);
  }
}

async function checkAccounts(config: ReturnType<typeof loadOpsConfig>, accountName?: string): Promise<void> {
  const accountNames = accountName ? [accountName] : Object.keys(config.accounts.accounts ?? {});
  if (accountNames.length === 0) {
    console.log("Accounts");
    console.log(`  None configured. Create config/accounts/${config.networkName}.json from the example file if write ops need accounts.`);
    return;
  }

  const results: AccountCheckResult[] = [];
  for (const name of accountNames) {
    results.push(await checkAccount(config, name));
  }

  console.log("Account checks");
  for (const result of results) {
    printAccountCheck(result);
  }

  if (results.some((result) => !result.ok)) {
    throw new Error("One or more account checks failed");
  }
}

function printAccountCheck(result: AccountCheckResult): void {
  console.log(`  ${result.name}`);
  console.log(`    Status:      ${result.ok ? "ok" : "failed"}`);
  console.log(`    Type:        ${result.type}`);
  console.log(`    Source:      ${result.source}`);
  if (result.resolvedPath && result.resolvedPath !== result.source) {
    console.log(`    Resolved:    ${result.resolvedPath}`);
  }
  if (result.address) console.log(`    Address:     ${result.address}`);
  if (result.error) console.log(`    Error:       ${result.error}`);
}

function printAccountAddress(accountName: string, source: AccountSource, address: string): void {
  console.log("Account");
  console.log(`  Name:    ${accountName}`);
  console.log(`  Type:    ${source.type}`);
  console.log(`  Source:  ${source.type === "privateKeyEnv" ? source.env : source.path}`);
  console.log(`  Address: ${address}`);
}

import { accountSource, listAccounts, loadAccountAddress } from "../accounts/load";
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

  throw new Error(`Unknown accounts command: ${command ?? "(missing)"}`);
}

function printAccountsHelp(): void {
  console.log(`Accounts commands

Usage:
  npm run ops -- accounts list --network <network>
  npm run ops -- accounts address --network <network> --account <name>

Commands:
  list       Print configured account aliases and sources. Does not read secrets.
  address    Resolve one configured account address from privateKeyEnv or keystore.

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
    if (account.passwordEnv) console.log(`    Password env: ${account.passwordEnv}`);
  }
}

function printAccountAddress(accountName: string, source: AccountSource, address: string): void {
  console.log("Account");
  console.log(`  Name:    ${accountName}`);
  console.log(`  Type:    ${source.type}`);
  console.log(`  Source:  ${source.type === "privateKeyEnv" ? source.env : source.path}`);
  console.log(`  Address: ${address}`);
}

import fs from "fs";
import path from "path";
import { ethers } from "ethers";
import { AccountCheckResult, accountSource, checkAccount, listAccounts, loadAccountAddress, promptHidden } from "../accounts/load";
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
  const options = parseOptions(rest, new Set(["show-private-key"]));

  if (command === "create-keystore") {
    await createKeystore(options);
    return;
  }
  if (command === "decrypt-keystore") {
    await decryptKeystore(options);
    return;
  }

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
  npm run ops -- accounts create-keystore --path <path> [--password-env <env>]
  npm run ops -- accounts decrypt-keystore --path <path> [--password-env <env>] [--show-private-key]

Commands:
  list       Print configured account aliases and sources. Does not read secrets.
  address    Resolve one configured account address from privateKeyEnv or keystore.
  check      Validate configured account sources and print derived addresses.
  create-keystore   Create an encrypted JSON keystore. Does not print the private key.
  decrypt-keystore  Decrypt a JSON keystore and print its address. Private key requires --show-private-key.

Account config:
  Copy config/accounts/<network>.example.json to config/accounts/<network>.json.
  Local account config files are ignored by git.
`);
}

async function createKeystore(options: Record<string, string>): Promise<void> {
  const outputPath = path.resolve(requireOption(options, "path"));
  if (fs.existsSync(outputPath)) throw new Error(`Refusing to overwrite existing keystore: ${outputPath}`);

  const password = await loadPassword("new keystore", options["password-env"], true);
  const wallet = ethers.Wallet.createRandom();
  const encryptedJson = await wallet.encrypt(password);

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, encryptedJson, { encoding: "utf8", flag: "wx", mode: 0o600 });

  console.log("Keystore created");
  console.log(`  Path:    ${outputPath}`);
  console.log(`  Address: ${wallet.address}`);
}

async function decryptKeystore(options: Record<string, string>): Promise<void> {
  const keystorePath = path.resolve(requireOption(options, "path"));
  const password = await loadPassword("keystore", options["password-env"], false);
  const wallet = await ethers.Wallet.fromEncryptedJson(fs.readFileSync(keystorePath, "utf8"), password);

  console.log("Keystore");
  console.log(`  Path:        ${keystorePath}`);
  console.log(`  Address:     ${wallet.address}`);
  if (options["show-private-key"]) {
    console.log(`  Private key: ${wallet.privateKey}`);
  } else {
    console.log("  Private key: hidden; rerun with --show-private-key to print it");
  }
}

async function loadPassword(label: string, passwordEnv: string | undefined, confirm: boolean): Promise<string> {
  let password: string;
  if (passwordEnv) {
    if (process.env[passwordEnv] === undefined) throw new Error(`Environment variable ${passwordEnv} is not set`);
    password = process.env[passwordEnv] ?? "";
  } else {
    password = await promptHidden(`Password for ${label}: `);
  }

  if (!confirm) return password;

  const confirmation = passwordEnv ? password : await promptHidden(`Confirm password for ${label}: `);
  if (confirmation !== password) throw new Error("Passwords do not match");
  return password;
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

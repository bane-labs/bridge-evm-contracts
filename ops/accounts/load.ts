import fs from "fs";
import path from "path";
import { ethers } from "ethers";
import { AccountSource, OpsConfig } from "../config/types";

export interface AccountSummary {
  name: string;
  type: AccountSource["type"];
  source: string;
  passwordEnv?: string;
}

export function listAccounts(config: OpsConfig): AccountSummary[] {
  return Object.entries(config.accounts.accounts ?? {}).map(([name, source]) => ({
    name,
    type: source.type,
    source: describeSource(source),
    passwordEnv: source.type === "keystore" ? source.passwordEnv : undefined
  }));
}

export async function loadAccountAddress(config: OpsConfig, accountName: string): Promise<string> {
  const source = config.accounts.accounts?.[accountName];
  if (!source) {
    throw new Error(`Account "${accountName}" is not configured for ${config.networkName}`);
  }

  if (source.type === "privateKeyEnv") {
    const privateKey = process.env[source.env];
    if (!privateKey) throw new Error(`Environment variable ${source.env} is not set for account "${accountName}"`);
    return new ethers.Wallet(privateKey).address;
  }

  const walletJson = fs.readFileSync(resolveAccountPath(source.path), "utf8");
  const password = await loadAccountPassword(accountName, source.passwordEnv);
  const wallet = await ethers.Wallet.fromEncryptedJson(walletJson, password);
  return wallet.address;
}

export function accountSource(config: OpsConfig, accountName: string): AccountSource {
  const source = config.accounts.accounts?.[accountName];
  if (!source) throw new Error(`Account "${accountName}" is not configured for ${config.networkName}`);
  return source;
}

function describeSource(source: AccountSource): string {
  if (source.type === "privateKeyEnv") return source.env;
  return source.path;
}

function resolveAccountPath(accountPath: string): string {
  return path.isAbsolute(accountPath) ? accountPath : path.resolve(accountPath);
}

async function loadAccountPassword(accountName: string, passwordEnv?: string): Promise<string> {
  if (passwordEnv && process.env[passwordEnv] !== undefined) return process.env[passwordEnv] ?? "";
  return promptHidden(passwordEnv
    ? `Password for account "${accountName}" (${passwordEnv} fallback): `
    : `Password for account "${accountName}": `);
}

function promptHidden(prompt: string): Promise<string> {
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    throw new Error("Password prompt requires a TTY. Set the configured password env var in non-interactive environments.");
  }

  return new Promise((resolve, reject) => {
    const stdin = process.stdin;
    const stdout = process.stdout;
    const wasRaw = stdin.isRaw === true;
    let password = "";

    const cleanup = (): void => {
      stdin.removeListener("data", onData);
      stdin.setRawMode(wasRaw);
      stdin.pause();
      stdout.write("\n");
    };

    const onData = (data: Buffer | string): void => {
      const input = data.toString("utf8");
      for (const char of input) {
        if (char === "\r" || char === "\n" || char === "\u0004") {
          cleanup();
          resolve(password);
          return;
        }
        if (char === "\u0003") {
          cleanup();
          reject(new Error("Password prompt cancelled"));
          return;
        }
        if (char === "\u007f") {
          password = password.slice(0, -1);
          continue;
        }
        password += char;
      }
    };

    stdout.write(prompt);
    stdin.setRawMode(true);
    stdin.resume();
    stdin.on("data", onData);
  });
}

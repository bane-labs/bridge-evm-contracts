import { runAccountsCommand } from "./commands/accounts";
import { runBridgeCommand } from "./commands/bridge";
import { runConfigCommand } from "./commands/config";
import { runMessageCommand } from "./commands/message";

async function main(): Promise<void> {
  const [group, ...args] = process.argv.slice(2);
  if (!group || group === "help" || group === "--help" || group === "-h") {
    printHelp();
    return;
  }

  if (group === "config") {
    runConfigCommand(args);
    return;
  }
  if (group === "bridge") {
    await runBridgeCommand(args);
    return;
  }
  if (group === "message" || group === "message-bridge") {
    await runMessageCommand(args);
    return;
  }
  if (group === "accounts" || group === "account") {
    await runAccountsCommand(args);
    return;
  }

  throw new Error(`Unknown ops command group: ${group}`);
}

function printHelp(): void {
  console.log(`Bridge ops CLI

Usage:
  npm run ops -- help
  npm run ops -- <group> --help
  npm run ops -- config show --network <network>
  npm run ops -- accounts list --network <network>
  npm run ops -- accounts address --network <network> --account <name>
  npm run ops -- accounts check --network <network> [--account <name>]
  npm run ops -- bridge state --network <network> [--bridge <address>] [--max-tokens <count>]
  npm run ops -- bridge token --network <network> --token <alias-or-address> [--bridge <address>]
  npm run ops -- bridge claimable --network <network> --nonce <nonce> [--token <alias-or-address>] [--bridge <address>]
  npm run ops -- message state --network <network> [--message-bridge <address>]
  npm run ops -- message get --network <network> --nonce <nonce> [--message-bridge <address>]
  npm run ops -- message result --network <network> --nonce <nonce> [--message-bridge <address>]
  npm run ops -- message executable --network <network> --nonce <nonce> [--message-bridge <address>]

Networks:
  local, neox-devnet, neox-testnet, neox-mainnet

Groups:
  config      Inspect resolved config.
  accounts    Inspect configured local accounts.
  bridge      Read token bridge state.
  message     Read message bridge state.
`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});

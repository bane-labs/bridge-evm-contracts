import { runBridgeCommand } from "./commands/bridge";
import { runConfigCommand } from "./commands/config";

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

  throw new Error(`Unknown ops command group: ${group}`);
}

function printHelp(): void {
  console.log(`Bridge ops CLI

Usage:
  npm run ops -- config show --network <network>
  npm run ops -- bridge state --network <network> [--bridge <address>] [--max-tokens <count>]
  npm run ops -- bridge token --network <network> --token <alias-or-address> [--bridge <address>]
  npm run ops -- bridge claimable --network <network> --nonce <nonce> [--token <alias-or-address>] [--bridge <address>]

Networks:
  local, neox-devnet, neox-testnet, neox-mainnet
`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});

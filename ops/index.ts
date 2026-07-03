import { runAccountsCommand } from "./commands/accounts";
import { runBridgeCommand } from "./commands/bridge";
import { runConfigCommand } from "./commands/config";
import { runMessageCommand } from "./commands/message";
import { runNeoTokenCommand } from "./commands/neoToken";

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
  if (group === "neo-token") {
    await runNeoTokenCommand(args);
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
  npm run ops -- accounts create-keystore --path <path> [--password-env <env>]
  npm run ops -- accounts decrypt-keystore --path <path> [--password-env <env>] [--show-private-key]
  npm run ops -- bridge state --network <network> [--bridge <address>] [--max-tokens <count>]
  npm run ops -- bridge token --network <network> --token <alias-or-address> [--bridge <address>]
  npm run ops -- bridge claimable --network <network> --nonce <nonce> [--token <alias-or-address>] [--bridge <address>]
  npm run ops -- bridge claim-native --network <network> --account <name> --nonce <nonce> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge claim-token --network <network> --account <name> --token <alias-or-address> --nonce <nonce> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge withdraw-native --network <network> --account <name> --to <address> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge withdraw-token --network <network> --account <name> --token <alias-or-address> --to <address> --amount <tokens> [--bridge <address>] [--approve] [--dry-run true] [--yes]
  npm run ops -- bridge fund-native --network <network> --account <name> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge fund-token --network <network> --account <name> --token <alias-or-address> --amount <tokens> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge pause --network <network> --account <name> --target <bridge|withdrawals|native|token|all> [--token <alias-or-address>] [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge unpause --network <network> --account <name> --target <bridge|withdrawals|native|token|all> [--token <alias-or-address>] [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge configure-native --network <network> --account <name> --fee <eth> --min <eth> --max <eth> --max-deposits <count> --decimals-here <count> --decimals-n3 <count> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge set-native-fee --network <network> --account <name> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge set-native-min --network <network> --account <name> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge set-native-max --network <network> --account <name> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge set-native-max-deposits --network <network> --account <name> --max-deposits <count> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge set-token-fee --network <network> --account <name> --token <alias-or-address> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge set-token-min --network <network> --account <name> --token <alias-or-address> --amount <tokens> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge set-token-max --network <network> --account <name> --token <alias-or-address> --amount <tokens> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge set-token-max-deposits --network <network> --account <name> --token <alias-or-address> --max-deposits <count> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge register-token --network <network> --account <name> --token <alias-or-address> --neo-n3-token <address> --fee <eth> --min <tokens> --max <tokens> --max-deposits <count> [--scaling-factor <count>] [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- neo-token state --network <network> [--neo-token <address>]
  npm run ops -- neo-token total-supply --network <network> [--neo-token <address>]
  npm run ops -- neo-token balance-of --network <network> --holder <address> [--neo-token <address>]
  npm run ops -- neo-token owner --network <network> [--neo-token <address>]
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

Networks:
  local, neox-devnet, neox-testnet, neox-mainnet, neox-mainnet-fork

Groups:
  config      Inspect resolved config.
  accounts    Inspect configured local accounts.
  bridge      Read bridge state and run guarded bridge operations.
  neo-token   Read NeoToken state.
  message     Read message bridge state and run guarded message operations.
`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
